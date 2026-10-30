## Recommend

This project no longer adds new features and is only for daily maintenance. It is recommended to use the docker-compose version. Project link: https://github.com/linuxeye/bypanel

[Aliyun ECS recommend](https://www.aliyun.com/daily-act/ecs/activity_selection?userCode=ird24dsz)

## lnmp
This script is written using the shell, in order to quickly deploy `LEMP`/`LAMP`/`LNMP`/`LNMPA`/`LTMP`(Linux, Nginx/Tengine/OpenResty, MySQL in a production environment/MariaDB/Percona, PHP, JAVA), applicable to RHEL 7, 8, 9(including CentOS,RedHat,AlmaLinux,Rocky), Debian 9, 10, 11, 12, Ubuntu 16, 18, 20, 22, 24 and Fedora 27+ of 64.

Script properties:
- Continually updated, Provide Shell Interaction and Autoinstall
- Source compiler installation, most stable source is the latest version, and download from the official site
- Some security optimization
- Providing a plurality of database versions (MySQL-8.4, MySQL-8.0, MySQL-5.7, MySQL-5.5, MariaDB-11.8, MariaDB-11.4, MariaDB-10.11, MariaDB-5.5, Percona-8.4, Percona-8.0, Percona-5.7, Percona-5.5, PostgreSQL, MongoDB)
- Providing multiple PHP versions (PHP-8.5, PHP-8.4, PHP-8.3, PHP-8.2, PHP-8.1, PHP-8.0, PHP-7.4, PHP-7.3, PHP-7.2, PHP-7.1, PHP-7.0, PHP-5.6, PHP-5.5, PHP-5.4, PHP-5.3)
- Provide Nginx, Tengine, OpenResty, Apache and ngx_lua_waf
- Providing a plurality of Tomcat version (Tomcat-10, Tomcat-9, Tomcat-8, Tomcat-7)
- Providing a plurality of JDK version (OpenJDK-8, OpenJDK-11, OpenJDK-17)
- According to their needs to install PHP Cache Accelerator provides ZendOPcache, apcu, eAccelerator. And php extensions,include ZendGuardLoader,ionCube,SourceGuardian,imagick,gmagick,fileinfo,imap,ldap,calendar,phalcon,yaf,yar,redis,memcached,memcache,mongodb,swoole,xdebug
- Installation Nodejs, Pureftpd, phpMyAdmin according to their needs
- Install memcached, redis according to their needs
- Jemalloc optimize MySQL, Nginx
- Providing add a virtual host script, include Let's Encrypt SSL certificate
- Provide Nginx/Tengine/OpenResty/Apache/Tomcat, MySQL/MariaDB/Percona, PHP, Redis, Memcached, phpMyAdmin upgrade script
- Provide local,remote(rsync between servers),Aliyun OSS,Qcloud COS,UPYUN,QINIU,Amazon S3,Google Drive and Dropbox backup script

## Installation

Install the dependencies for your distro, download the source and run the installation script.

#### CentOS/Redhat

```bash
yum -y install wget screen
```

#### Debian/Ubuntu

```bash
apt-get -y install wget screen
```

#### Download Source and Install

```bash
wget http://mirrors.linuxeye.com/lnmp-full.tar.gz
# wget https://downloads.sourceforge.net/project/linuxeye/lnmp-full.tar.gz
tar xzf lnmp-full.tar.gz
cd lnmp
```

If you disconnect during installation, you can execute the command `screen -r lnmp` to reconnect to the install window
```bash
screen -S lnmp
```

If you need to modify the directory (installation, data storage, Nginx logs), modify `options.conf` file before running install.sh
```bash
./install.sh
```

### Docker containers

Install the `supervisor` package in the image before running the installer.
Inside Docker, LNMP uses Supervisor for service registration and lifecycle
operations. It does not deploy systemd units, register SysV boot services, or
reboot the container. The installer may start Supervisor temporarily when a
service is needed during installation (for example, database initialization).

Use the foreground entrypoint at runtime:

```dockerfile
ENTRYPOINT ["/bin/bash", "/path/to/lnmp/container-entrypoint.sh"]
```

An existing `supervisord -n -c /etc/supervisor/supervisord.conf` entrypoint also
works. Existing included program sections are reused; missing programs receive
individual `lnmp-*.conf` files in `/etc/supervisor/conf.d`. Default and additional
PHP-FPM installations use separate programs and sockets. Nginx upgrades restart
the supervised process instead of forking a replacement master outside Supervisor.

```bash
bash service-control.sh status nginx
bash service-control.sh reload nginx
bash service-control.sh restart php74-fpm
```

Container detection is automatic; set `LNMP_CONTAINER=1` to force it or `0` for
host service management. For a custom Supervisor layout, set
`LNMP_SUPERVISOR_CONFIG` and `LNMP_SUPERVISOR_DIR` consistently during installation
and runtime, and include the latter directory's `*.conf` files in the main config.
Upgrades and management commands require Supervisor to be running; they return
an error if it is unavailable. Supervisor's foreground mode is described in the
[official documentation](https://supervisord.org/running.html).

## How to install another PHP version

```bash
~/lnmp/install.sh --mphp_ver 54

```

## How to add Extensions

```bash
~/lnmp/addons.sh

```

## How to add a virtual host

```bash
~/lnmp/vhost.sh
```

## How to delete a virtual host

```bash
~/lnmp/vhost.sh --del
```

## How to add FTP virtual user

```bash
~/lnmp/pureftpd_vhost.sh
```

## How to backup

```bash
~/lnmp/backup_setup.sh    // Backup parameters
~/lnmp/backup.sh    // Perform the backup immediately
crontab -l    // Can be added to scheduled tasks, such as automatic backups every day 1:00
  0 1 * * * cd ~/lnmp/backup.sh  > /dev/null 2>&1 &
```

## How to manage service

Nginx/Tengine/OpenResty:
```bash
systemctl {start|stop|status|restart|reload} nginx
```
MySQL/MariaDB/Percona:
```bash
systemctl {start|stop|restart|reload|status} mysqld
```
PostgreSQL:
```bash
systemctl {start|stop|restart|status} postgresql
```
MongoDB:
```bash
systemctl {start|stop|status|restart|reload} mongod
```
PHP:
```bash
systemctl {start|stop|restart|reload|status} php-fpm
```
Apache:
```bash
systemctl {start|restart|stop} httpd
```
Tomcat:
```bash
systemctl {start|stop|status|restart} tomcat
```
Pure-FTPd:
```bash
systemctl {start|stop|restart|status} pureftpd
```
Redis:
```bash
systemctl {start|stop|status|restart|reload} redis-server
```
Memcached:
```bash
systemctl {start|stop|status|restart|reload} memcached
```

## How to upgrade

PHP 7.4.33, 8.0.30 and 8.1.34 installations and upgrades automatically apply
the upstream source backports for CVE-2026-109618 and CVE-2026-109619 before
compilation. A failed download or patch stops the operation. These backports
do not restore general security support for these end-of-life branches.
See the [official advisory](https://www.php.net/archive/2026.php#2026-10-21-5).

Existing installations must be rebuilt, even if the version number is unchanged:

```bash
./upgrade.sh --php 7.4.33
# or: ./upgrade.sh --php 8.0.30
# or: ./upgrade.sh --php 8.1.34
```

These commands upgrade the default PHP installation configured in `options.conf`.
Additional PHP installations must each be rebuilt separately using their own
installation path. PHP 7.3 and older are not covered by these backports.

```bash
~/lnmp/upgrade.sh
```

## How to uninstall

```bash
~/lnmp/uninstall.sh
```
