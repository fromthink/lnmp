#!/bin/bash
# Run in a disposable LNMP image with Supervisor, Nginx and PHP-FPM installed.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d /tmp/lnmp-services.XXXXXX)
trap 'supervisorctl -c "${work}/supervisord.conf" shutdown >/dev/null 2>&1 || :; rm -rf "${work}"' EXIT
export LNMP_CONTAINER=auto
export LNMP_SUPERVISOR_CONFIG=${work}/supervisord.conf
export LNMP_SUPERVISOR_DIR=${work}/conf.d
mkdir -p "${LNMP_SUPERVISOR_DIR}" "${work}/nginx/sbin" "${work}/nginx/conf" "${work}/php/sbin" "${work}/php/etc" "${work}/php74/sbin" "${work}/php74/etc"
chmod 755 "${work}"
nginx_install_dir=${work}/nginx
web_install_dir=${nginx_install_dir}
php_install_dir=${work}/php
ln -s /usr/local/nginx/sbin/nginx "${nginx_install_dir}/sbin/nginx"
ln -s /usr/local/php/sbin/php-fpm "${php_install_dir}/sbin/php-fpm"
ln -s /usr/local/php74/sbin/php-fpm "${php_install_dir}74/sbin/php-fpm"
cat > "${nginx_install_dir}/conf/nginx.conf" <<CONF
pid ${work}/nginx.pid;
error_log stderr;
events { worker_connections 16; }
CONF
for name in php php74; do
  cat > "${work}/${name}/etc/php-fpm.conf" <<CONF
[global]
pid = ${work}/${name}.pid
error_log = /proc/self/fd/2
[www]
user = www
group = www
listen = ${work}/${name}.sock
pm = static
pm.max_children = 1
CONF
done
. "${repo}/include/service.sh"
LNMP_Is_Container || { echo "Container/build environment misdetected as host" >&2; exit 1; }
LNMP_Supervisor_Setup
grep -q "files=${LNMP_SUPERVISOR_DIR}/\*.conf" "${LNMP_SUPERVISOR_CONFIG}"
cat > "${LNMP_SUPERVISOR_CONFIG}" <<CONF
[unix_http_server]
file=${work}/supervisor.sock
chmod=0700
[supervisord]
logfile=${work}/supervisord.log
pidfile=${work}/supervisord.pid
childlogdir=${work}
[rpcinterface:supervisor]
supervisor.rpcinterface_factory=supervisor.rpcinterface:make_main_rpcinterface
[supervisorctl]
serverurl=unix://${work}/supervisor.sock
[include]
files=${work}/existing.conf ${LNMP_SUPERVISOR_DIR}/*.conf
CONF
# Fake host commands must never be called in container mode.
mkdir "${work}/bin"
for name in systemctl service chkconfig update-rc.d reboot; do
  printf '#!/bin/bash\necho "Host init command invoked" >&2\nexit 99\n' > "${work}/bin/${name}"
  chmod +x "${work}/bin/${name}"
done
export PATH=${work}/bin:${PATH}
LNMP_SUPERVISOR_BOOTSTRAP=1
systemctl enable nginx
systemctl start nginx
systemctl start php-fpm
main_pid=$(LNMP_Supervisor_Ctl pid php-fpm)
php_install_dir=${work}/php74
sed -i "s@${work}/php74.sock@/dev/shm/php-cgi.sock@" "${php_install_dir}/etc/php-fpm.conf"
systemctl enable php-fpm
systemctl start php-fpm
grep -q '/dev/shm/php74-cgi.sock' "${php_install_dir}/etc/php-fpm.conf"
[ -S /dev/shm/php74-cgi.sock ]
[ "$(LNMP_Service_Name php-fpm)" = php74-fpm ]
[ "$(LNMP_Supervisor_Ctl pid php-fpm)" = "${main_pid}" ]
# Reload the new PHP service without replacing or stopping the default service.
service php-fpm reload
sleep 1
[ "$(LNMP_Supervisor_Ctl pid php-fpm)" = "${main_pid}" ]
service php-fpm stop
service php-fpm stop
service php-fpm start
php_install_dir=${work}/php
old_pid=$(LNMP_Supervisor_Ctl pid nginx)
service nginx restart
[ "$(LNMP_Supervisor_Ctl pid nginx)" != "${old_pid}" ]
service nginx reload
# Exercise the standalone command used by certificate renewal hooks.
mkdir -p "${work}/repo/include"
cp "${repo}/service-control.sh" "${work}/repo/"
cp "${repo}/include/service.sh" "${work}/repo/include/"
# The working checkout contains existing CRLF files; normalize only the
# disposable fixture to represent a Linux checkout, never the repository.
tr -d '\r' < "${repo}/include/check_dir.sh" > "${work}/repo/include/check_dir.sh"
printf 'nginx_install_dir=%q\nphp_install_dir=%q\n' "${nginx_install_dir}" "${php_install_dir}" > "${work}/repo/options.conf"
bash "${work}/repo/service-control.sh" status nginx
bash "${work}/repo/service-control.sh" reload nginx
bash "${repo}/container-entrypoint.sh" /bin/true
# A failed child process must be reported, not silently skipped.
cat > "${LNMP_SUPERVISOR_DIR}/broken.conf" <<CONF
[program:httpd]
command=/bin/false
autostart=false
startsecs=1
startretries=0
CONF
if service httpd start; then echo 'Broken service unexpectedly succeeded' >&2; exit 1; fi
systemctl disable httpd
# Existing combined files must not be duplicated or lose neighboring programs.
cat "${LNMP_SUPERVISOR_DIR}/lnmp-php74-fpm.conf" > "${work}/existing.conf"
cat >> "${work}/existing.conf" <<CONF
[program:preserved]
command=/bin/sleep 300
autostart=false
CONF
rm "${LNMP_SUPERVISOR_DIR}/lnmp-php74-fpm.conf"
systemctl enable php74-fpm
[ ! -e "${LNMP_SUPERVISOR_DIR}/lnmp-php74-fpm.conf" ]
systemctl disable php74-fpm
grep -q '^\[program:preserved\]' "${work}/existing.conf"
! grep -q '^\[program:php74-fpm\]' "${work}/existing.conf"
[ "$(LNMP_Supervisor_Ctl pid php-fpm)" = "${main_pid}" ]
# Optional real PostgreSQL coverage: mirror enable -> initdb -> start from
# Install_PostgreSQL, including an unprivileged database process.
if [ -n "${LNMP_TEST_PGSQL_DIR:-}" ]; then
  pgsql_install_dir=${LNMP_TEST_PGSQL_DIR}
  pgsql_data_dir=${work}/pgdata
  id postgres >/dev/null 2>&1 || useradd -d "${work}" -s /bin/bash postgres
  mkdir -p "${pgsql_data_dir}" "${work}/pgsocket"
  chown postgres:postgres "${pgsql_data_dir}" "${work}/pgsocket"
  systemctl enable postgresql
  su - postgres -c "${pgsql_install_dir}/bin/initdb -D ${pgsql_data_dir} -A trust --no-locale"
  printf "unix_socket_directories = '%s'\nlisten_addresses = ''\n" "${work}/pgsocket" >> "${pgsql_data_dir}/postgresql.conf"
  systemctl start postgresql
  su - postgres -c "${pgsql_install_dir}/bin/psql -h ${work}/pgsocket -d postgres -v ON_ERROR_STOP=1 -c 'SELECT 1'"
  systemctl reload postgresql
  systemctl stop postgresql
  systemctl start postgresql
  systemctl disable postgresql
  echo 'PASS: PostgreSQL initdb, SQL query, reload, stop/start, unregister.'
fi
systemctl restart rsyslog ssh
chkconfig mysqld on
update-rc.d mysqld defaults
reboot
# Errors must remain observable rather than being reported as success.
if systemctl start unknown-service; then echo 'Unknown service unexpectedly succeeded' >&2; exit 1; fi
LNMP_Supervisor_Ctl shutdown
sleep 1
LNMP_SUPERVISOR_BOOTSTRAP=0
if service nginx start; then echo 'Missing Supervisor unexpectedly succeeded' >&2; exit 1; fi
if bash "${work}/repo/service-control.sh" start nginx; then echo 'CLI hid Supervisor failure' >&2; exit 1; fi
LNMP_CONTAINER=0
if systemctl status nginx; then
  echo 'Native fallback unexpectedly succeeded' >&2; exit 1
else
  [ "$?" = 99 ]
fi
printf 'PASS: real Nginx/PHP-FPM lifecycle, separate PHP versions, reload/restart, combined-config cleanup, no host init, failure propagation.\n'
