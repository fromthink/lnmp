#!/bin/bash

# Build the bundled GMP extension for the selected PHP installation.
Install_GMP() (
  set -e
  if [ ! -x "${php_install_dir}/bin/phpize" ]; then
    echo "${CFAILURE}PHP must be installed before GMP.${CEND}"
    exit 1
  fi
  if "${php_install_dir}/bin/php" -r 'exit(extension_loaded("gmp") ? 0 : 1);'; then
    echo "${CSUCCESS}PHP GMP module already enabled.${CEND}"
    exit 0
  fi
  case "${PM}" in
    yum) yum -y install gmp-devel ;;
    apt-get) apt-get -y install libgmp-dev ;;
    *) echo "${CFAILURE}Unsupported package manager for GMP: ${PM}${CEND}"; exit 1 ;;
  esac
  cd "${current_dir}/src"
  PHP_detail_ver=$("${php_install_dir}/bin/php-config" --version)
  src_url="https://www.php.net/distributions/php-${PHP_detail_ver}.tar.gz"
  Download_src
  # Keep the build separate from other extensions' source trees.
  gmp_build_dir=$(mktemp -d "${current_dir}/src/gmp-build.XXXXXX")
  trap 'rm -rf -- "${gmp_build_dir}"' EXIT
  tar xzf "php-${PHP_detail_ver}.tar.gz" -C "${gmp_build_dir}"
  cd "${gmp_build_dir}/php-${PHP_detail_ver}/ext/gmp"
  "${php_install_dir}/bin/phpize"
  ./configure --with-php-config="${php_install_dir}/bin/php-config" --with-gmp
  make -j "${THREAD:-1}"
  make install
  phpExtensionDir=$("${php_install_dir}/bin/php-config" --extension-dir)
  test -f "${phpExtensionDir}/gmp.so"
  "${php_install_dir}/bin/php" -n -d "extension=${phpExtensionDir}/gmp.so" \
    -r 'exit(extension_loaded("gmp") ? 0 : 1);'
  mkdir -p "${php_install_dir}/etc/php.d"
  echo 'extension=gmp.so' > "${php_install_dir}/etc/php.d/04-gmp.ini"
  "${php_install_dir}/bin/php" -r 'exit(extension_loaded("gmp") ? 0 : 1);'
  echo "${CSUCCESS}PHP GMP module installed successfully!${CEND}"
)
