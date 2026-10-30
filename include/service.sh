#!/bin/bash
# Keep legacy installer calls behind one container-aware service boundary.
LNMP_Is_Container() {
  case "${LNMP_CONTAINER:-auto}" in
    1) return 0 ;;
    0) return 1 ;;
    auto)
      # BuildKit RUN steps may have no container marker and cgroup "0::/".
      # Without a running systemd instance, use Supervisor rather than falling
      # through to host systemctl. LNMP_CONTAINER=0 still forces host handling.
      [ -e /.dockerenv ] || [ -e /run/.containerenv ] ||
        grep -qaE '(docker|containerd|kubepods|lxc)' /proc/1/cgroup ||
        [ ! -d /run/systemd/system ]
      ;;
    *) echo 'LNMP_CONTAINER must be auto, 0 or 1.' >&2; return 2 ;;
  esac
}

case "${LNMP_CONTAINER:-auto}" in
  auto|0|1) ;;
  *) echo 'LNMP_CONTAINER must be auto, 0 or 1.' >&2; return 1 ;;
esac
LNMP_BASE_PHP_DIR=${LNMP_BASE_PHP_DIR:-${php_install_dir}}
LNMP_SUPERVISOR_CONFIG=${LNMP_SUPERVISOR_CONFIG:-/etc/supervisor/supervisord.conf}
LNMP_SUPERVISOR_DIR=${LNMP_SUPERVISOR_DIR:-/etc/supervisor/conf.d}

LNMP_Supervisor_Setup() {
  command -v supervisorctl >/dev/null && command -v supervisord >/dev/null || {
    echo 'Install the supervisor package in the container before running LNMP.' >&2
    return 1
  }
  mkdir -p "${LNMP_SUPERVISOR_DIR}" /var/log/supervisor || return 1
  if [ ! -e "${LNMP_SUPERVISOR_CONFIG}" ]; then
    mkdir -p "$(dirname "${LNMP_SUPERVISOR_CONFIG}")" || return 1
    cat > "${LNMP_SUPERVISOR_CONFIG}" <<CONF
[unix_http_server]
file=/var/run/supervisor.sock
chmod=0700
[supervisord]
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor
[rpcinterface:supervisor]
supervisor.rpcinterface_factory=supervisor.rpcinterface:make_main_rpcinterface
[supervisorctl]
serverurl=unix:///var/run/supervisor.sock
[include]
files=${LNMP_SUPERVISOR_DIR}/*.conf
CONF
  fi
}

LNMP_Supervisor_Ctl() {
  command supervisorctl -c "${LNMP_SUPERVISOR_CONFIG}" "$@"
}

# Expand only the include patterns used by this Supervisor configuration.
LNMP_Supervisor_Files() {
  local pattern file
  while IFS= read -r pattern; do
    case "${pattern}" in /*) ;; *) pattern="$(dirname "${LNMP_SUPERVISOR_CONFIG}")/${pattern}" ;; esac
    for file in ${pattern}; do [ ! -f "${file}" ] || printf '%s\n' "${file}"; done
  done < <(awk '/^\[/{ include_section=($0 ~ /^\[include\]/) } include_section && /^[[:space:]]*files[[:space:]]*=/ { sub(/^[^=]*=[[:space:]]*/, ""); sub(/[;#].*$/, ""); for (i=1;i<=NF;i++) print $i }' "${LNMP_SUPERVISOR_CONFIG}")
  printf '%s\n' "${LNMP_SUPERVISOR_CONFIG}"
}

LNMP_Supervisor_Find() {
  local file
  while IFS= read -r file; do
    if grep -Eq "^\[program:$1\][[:space:]]*$" "${file}"; then printf '%s\n' "${file}"; return 0; fi
  done < <(LNMP_Supervisor_Files)
  return 1
}

LNMP_Service_Name() {
  local name=${1%.service} suffix
  if [ "${name}" = php-fpm ] && [ "${php_install_dir}" != "${LNMP_BASE_PHP_DIR}" ]; then
    suffix=${php_install_dir#"${LNMP_BASE_PHP_DIR}"}
    [[ "${suffix}" =~ ^[0-9]{2}$ ]] || { echo 'Cannot determine the PHP-FPM service name.' >&2; return 1; }
    name=php${suffix}-fpm
  fi
  [[ "${name}" =~ ^[a-zA-Z0-9_-]+$ ]] || return 1
  printf '%s\n' "${name}"
}

LNMP_Supervisor_Register() {
  local name=$1 binary cmd user=root signal=TERM dir path conf tmp file included=0 environment=
  LNMP_Supervisor_Setup || return 1
  # Existing combined configurations (including /etc/supervisor/nginx.conf)
  # stay in use; never introduce a duplicate program section.
  LNMP_Supervisor_Find "${name}" >/dev/null && return 0
  case "${name}" in
    nginx)
      dir=${web_install_dir:-${nginx_install_dir}}
      binary=${dir}/sbin/nginx
      cmd="\"${binary}\" -c \"${dir}/conf/nginx.conf\" -g \"daemon off;\""; signal=QUIT ;;
    php-fpm|php[0-9][0-9]-fpm)
      dir=${LNMP_BASE_PHP_DIR}
      [ "${name}" = php-fpm ] || { path=${name#php}; dir=${dir}${path%-fpm}; }
      binary=${dir}/sbin/php-fpm
      cmd="\"${binary}\" --nodaemonize --fpm-config \"${dir}/etc/php-fpm.conf\""; signal=QUIT ;;
    httpd) binary=${apache_install_dir}/bin/httpd; cmd="\"${binary}\" -DFOREGROUND" ;;
    mysqld)
      dir=${db_install_dir}
      if [ -z "${dir}" ]; then
        for path in "${mysql_install_dir}" "${mariadb_install_dir}" "${percona_install_dir}"; do
          [ ! -x "${path}/bin/mysqld" ] || dir=${path}
        done
      fi
      binary=${dir}/bin/mysqld
      [ -x "${binary}" ] || binary=${dir}/sbin/mysqld
      cmd="\"${binary}\" --defaults-file=/etc/my.cnf --user=mysql"
      if [ -f /usr/local/lib/libjemalloc.so ]; then environment='environment=LD_PRELOAD="/usr/local/lib/libjemalloc.so"'; fi ;;
    redis-server)
      binary=${redis_install_dir}/bin/redis-server
      cmd="\"${binary}\" \"${redis_install_dir}/etc/redis.conf\" --daemonize no"; user=redis ;;
    memcached) binary=${memcached_install_dir}/bin/memcached; cmd="\"${binary}\" -u memcached -m 256 -c 1024 -l 127.0.0.1" ;;
    postgresql) binary=${pgsql_install_dir}/bin/postgres; cmd="\"${binary}\" -D \"${pgsql_data_dir}\""; user=postgres ;;
    mongod)
      binary=${mongo_install_dir}/bin/mongod; cmd="\"${binary}\" --config /etc/mongod.conf"; user=mongod
      ;;
    tomcat)
      binary=${tomcat_install_dir}/bin/catalina.sh; cmd="\"${binary}\" run"
      path=${JAVA_HOME:-}
      if [ -z "${path}" ]; then
        path=$(command -v java) || { echo 'Java is required for Tomcat.' >&2; return 1; }
        path=$(dirname "$(dirname "$(readlink -f "${path}")")")
      fi
      environment="environment=JAVA_HOME=\"${path//%/%%}\",JRE_HOME=\"${path//%/%%}\"" ;;
    pureftpd) binary=${pureftpd_install_dir}/sbin/pure-ftpd; cmd="\"${binary}\" \"${pureftpd_install_dir}/etc/pure-ftpd.conf\"" ;;
    fail2ban) binary=$(command -v fail2ban-server); cmd="\"${binary}\" -xf start" ;;
    *) echo "No Supervisor configuration for ${name}." >&2; return 1 ;;
  esac
  [ -x "${binary}" ] || { echo "Missing service executable: ${binary}" >&2; return 1; }
  conf=${LNMP_SUPERVISOR_DIR}/lnmp-${name}.conf
  # Refuse a file that the running Supervisor would never load.
  tmp=$(mktemp "${conf}.XXXXXX") || return 1
  cat > "${tmp}" <<CONF
[program:${name}]
command=${cmd//%/%%}
user=${user}
autostart=true
autorestart=true
startsecs=1
startretries=3
stopsignal=${signal}
stopwaitsecs=60
stopasgroup=true
killasgroup=true
${environment}
stdout_logfile=/var/log/supervisor/${name}_out.log
stderr_logfile=/var/log/supervisor/${name}_err.log
CONF
  mv "${tmp}" "${conf}" || return 1
  while IFS= read -r file; do [ "${file}" != "${conf}" ] || included=1; done < <(LNMP_Supervisor_Files)
  [ "${included}" = 1 ] || { rm -f "${conf}"; echo "Add ${LNMP_SUPERVISOR_DIR}/*.conf to [include] in ${LNMP_SUPERVISOR_CONFIG}." >&2; return 1; }
}

LNMP_Supervisor_Ready() {
  local i
  LNMP_Supervisor_Ctl pid >/dev/null 2>&1 && return 0
  # Installers sometimes need live databases to initialize users. Only install.sh
  # may bootstrap Supervisor; upgrades must not silently launch another daemon.
  [ "${LNMP_SUPERVISOR_BOOTSTRAP:-0}" = 1 ] || {
    echo "Supervisor is not running; start it with ${LNMP_SUPERVISOR_CONFIG}." >&2; return 1;
  }
  command supervisord -c "${LNMP_SUPERVISOR_CONFIG}" || return 1
  for ((i=0;i<30;i++)); do
    LNMP_Supervisor_Ctl pid >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}

LNMP_Supervisor_Wait() {
  local name=$1 status deadline=$((SECONDS + ${LNMP_SERVICE_START_TIMEOUT:-180}))
  while (( SECONDS < deadline )); do
    status=$(LNMP_Supervisor_Ctl status "${name}" 2>/dev/null) || :
    case "${status}" in
      *RUNNING*) return 0 ;;
      *STARTING*|*BACKOFF*) sleep 0.2 ;;
      *) echo "Service failed to start: ${status}" >&2; return 1 ;;
    esac
  done
  echo "Timed out starting ${name}." >&2
  return 1
}

LNMP_Container_Service() {
  local action=$1 name file tmp status signal
  name=$(LNMP_Service_Name "$2") || return 1
  case "${name}" in
    chronyd|firewalld|rsyslog|ssh|sshd)
      echo "Skipping host service ${name} in the container."; return 0 ;;
  esac
  case "${action}" in
    enable) LNMP_Supervisor_Register "${name}" ;;
    disable)
      LNMP_Supervisor_Setup || return 1
      file=$(LNMP_Supervisor_Find "${name}") || return 0
      if LNMP_Supervisor_Ctl pid >/dev/null 2>&1; then
        status=$(LNMP_Supervisor_Ctl status "${name}" 2>/dev/null) || :
        if [[ "${status}" =~ RUNNING|STARTING|BACKOFF ]]; then LNMP_Supervisor_Ctl stop "${name}" || return 1; fi
      fi
      tmp=$(mktemp "${file}.XXXXXX") || return 1
      awk -v section="[program:${name}]" '/^\[/{ header=$0; sub(/[[:space:]]+$/, "", header); skip=(header==section) } !skip {print}' "${file}" > "${tmp}" || { rm -f "${tmp}"; return 1; }
      # Keep unrelated sections in an existing combined configuration.
      cat "${tmp}" > "${file}"; rm -f "${tmp}"
      if LNMP_Supervisor_Ctl pid >/dev/null 2>&1; then
        LNMP_Supervisor_Ctl reread && LNMP_Supervisor_Ctl update "${name}"
      fi
      ;;
    start|restart|reload|try-restart|reload-or-restart)
      case "${name}" in
        php[0-9][0-9]-fpm)
          # A second FPM must never try to bind the default installation's socket.
          file=${LNMP_BASE_PHP_DIR}${name#php}
          file=${file%-fpm}/etc/php-fpm.conf
          sed -i "s@/dev/shm/php-cgi.sock@/dev/shm/${name%-fpm}-cgi.sock@g" "${file}" || return 1 ;;
        redis-server)
          mkdir -p /var/run/redis && chown redis:redis /var/run/redis || return 1 ;;
        mongod)
          mkdir -p /var/run/mongodb && chown mongod:mongod /var/run/mongodb || return 1
          sed -i 's/^\([[:space:]]*fork:\).*/\1 false/' /etc/mongod.conf || return 1 ;;
        pureftpd)
          sed -i 's/^[[:space:]]*Daemonize[[:space:]].*/Daemonize no/' "${pureftpd_install_dir}/etc/pure-ftpd.conf" || return 1 ;;
      esac
      LNMP_Supervisor_Register "${name}" && LNMP_Supervisor_Ready || return 1
      LNMP_Supervisor_Ctl reread && LNMP_Supervisor_Ctl update "${name}" || return 1
      status=$(LNMP_Supervisor_Ctl status "${name}" 2>/dev/null) || :
      case "${action}" in
        start)
          if [[ ! "${status}" =~ RUNNING|STARTING|BACKOFF ]]; then
            LNMP_Supervisor_Ctl start "${name}" || return 1
          fi
          LNMP_Supervisor_Wait "${name}"
          ;;
        reload)
          case "${name}" in
            nginx|httpd) signal=HUP ;;
            php*-fpm) signal=USR2 ;;
            postgresql) signal=HUP ;;
            *) echo "Reload is unsupported for ${name}." >&2; return 1 ;;
          esac
          LNMP_Supervisor_Ctl signal "${signal}" "${name}" ;;
        *) LNMP_Supervisor_Ctl restart "${name}" ;;
      esac
      ;;
    stop|status|is-active)
      LNMP_Supervisor_Setup && LNMP_Supervisor_Ready || return 1
      if [ "${action}" = stop ]; then
        status=$(LNMP_Supervisor_Ctl status "${name}" 2>/dev/null) || :
        [[ "${status}" =~ STOPPED|EXITED ]] || LNMP_Supervisor_Ctl stop "${name}"
      else LNMP_Supervisor_Ctl status "${name}"; fi
      ;;
    *) echo "Unsupported container service operation: ${action}" >&2; return 1 ;;
  esac
}

# Preserve existing call sites in sourced installers, but never invoke the host
# init system in Docker. Failures from Supervisor are returned to the caller.
systemctl() {
  if ! LNMP_Is_Container; then command systemctl "$@"; return $?; fi
  local action=$1 name result=0
  shift
  [ "${action}" != daemon-reload ] || return 0
  for name in "$@"; do LNMP_Container_Service "${action}" "${name}" || result=1; done
  return "${result}"
}
service() {
  if LNMP_Is_Container; then LNMP_Container_Service "$2" "$1"; else command service "$@"; fi
}
chkconfig() { if LNMP_Is_Container; then return 0; else command chkconfig "$@"; fi; }
update-rc.d() { if LNMP_Is_Container; then return 0; else command update-rc.d "$@"; fi; }
reboot() { if LNMP_Is_Container; then echo 'Container installation complete; restart the container through Docker.'; else command reboot "$@"; fi; }
