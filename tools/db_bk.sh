#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://linuxeye.com
#
#

. ../options.conf
. ../include/check_dir.sh

DBname=$1
LogFile=${backup_dir}/db.log
DumpFile=${backup_dir}/DB_${DBname}_$(date +%Y%m%d_%H%M%S).sql
NewFile=${backup_dir}/DB_${DBname}_$(date +%Y%m%d_%H%M%S).tgz
OldFile=${backup_dir}/DB_${DBname}_$(date +%Y%m%d --date="${expired_days} days ago")*.tgz

[ ! -e "${backup_dir}" ] && mkdir -p ${backup_dir}

DB_tmp=`${db_install_dir}/bin/mysql -uroot -p${dbrootpwd} -e "show databases\G" | grep ${DBname}`
[ -z "${DB_tmp}" ] && { echo "[${DBname}] not exist" >> ${LogFile} ;  exit 1 ; }

if [ -n "`ls ${OldFile} 2>/dev/null`" ]; then
  rm -f ${OldFile}
  echo "[${OldFile}] Delete Old File Success" >> ${LogFile}
else
  echo "[${OldFile}] Delete Old Backup File" >> ${LogFile}
fi

if [ -e "${NewFile}" ]; then
  echo "[${NewFile}] The Backup File is exists, Can't Backup" >> ${LogFile}
else
  ${db_install_dir}/bin/mysqldump -uroot -p${dbrootpwd} --databases ${DBname} > ${DumpFile}
  pushd ${backup_dir} > /dev/null
  tar czf ${NewFile} ${DumpFile##*/} >> ${LogFile} 2>&1
  echo "[${NewFile}] Backup success ">> ${LogFile}
  rm -f ${DumpFile}
  popd > /dev/null
fi
