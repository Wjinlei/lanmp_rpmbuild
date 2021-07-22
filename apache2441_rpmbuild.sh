#!/usr/bin/env bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
cur_dir=$(pwd)

include(){
    local include=${1}
    if [[ -s ${cur_dir}/tmps/include/${include}.sh ]];then
        . ${cur_dir}/tmps/include/${include}.sh
    else
        wget --no-check-certificate -cv -t3 -T60 -P tmps/include http://d.hws.com/linux/master/script/include/${include}.sh >/dev/null 2>&1
        if [ "$?" -ne 0 ]; then
            echo "Error: ${cur_dir}/tmps/include/${include}.sh not found, shell can not be executed."
            exit 1
        fi
        . ${cur_dir}/tmps/include/${include}.sh
    fi
}

_install_apache_depend(){
    _info "Starting to install dependencies packages for Apache..."
    if [ "${PM}" = "yum" ];then
        local yum_depends=(python2-devel expat-devel zlib-devel)
        for depend in ${yum_depends[@]}
        do
            InstallPack "yum -y install ${depend}"
        done
    elif [ "${PM}" = "apt-get" ];then
        local apt_depends=(python-dev libexpat1-dev zlib1g-dev)
        for depend in ${apt_depends[@]}
        do
            InstallPack "apt-get -y install ${depend}"
        done
    fi
    CheckInstalled "_install_pcre" ${pcre_location}
    CheckInstalled "_install_openssl102" ${openssl102_location}
    _install_nghttp2
    _install_icu4c
    _install_libxml2
    _install_curl

    id -u www >/dev/null 2>&1
    [ $? -ne 0 ] && useradd -M -U www -d /home/www -s /sbin/nologin
    mkdir -p ${apache_location}
    _success "Install dependencies packages for Apache completed..."
}

_install_icu4c() {
    cd /tmp
    _info "${icu4c_filename} install start..."
    rm -fr ${icu4c_dirname}
    DownloadFile "${icu4c_filename}.tgz" "${icu4c_download_url}"
    tar zxf ${icu4c_filename}.tgz
    cd ${icu4c_dirname}/source
    CheckError "./configure --prefix=${icu4c_location}"
    CheckError "parallel_make"
    CheckError "make install"
    AddToEnv "${icu4c_location}"
    CreateLib64Dir "${icu4c_location}"
    if ! grep -qE "^${icu4c_location}/lib" /etc/ld.so.conf.d/*.conf; then
        echo "${icu4c_location}/lib" > /etc/ld.so.conf.d/icu4c.conf
    fi
    ldconfig
    _success "${icu4c_filename} install completed..."
    rm -f /tmp/${icu4c_filename}.tgz
    rm -fr /tmp/${icu4c_dirname}
}

_install_libxml2() {
    cd /tmp
    _info "${libxml2_filename} install start..."
    rm -fr ${libxml2_filename}
    DownloadFile "${libxml2_filename}.tar.gz" "${libxml2_download_url}"
    tar zxf ${libxml2_filename}.tar.gz
    cd ${libxml2_filename}
    CheckError "./configure --prefix=${libxml2_location} --with-icu=${icu4c_location}"
    CheckError "parallel_make"
    CheckError "make install"
    AddToEnv "${libxml2_location}"
    CreateLib64Dir "${libxml2_location}"
    if ! grep -qE "^${libxml2_location}/lib" /etc/ld.so.conf.d/*.conf; then
        echo "${libxml2_location}/lib" > /etc/ld.so.conf.d/libxml2.conf
    fi
    ldconfig
    _success "${libxml2_filename} install completed..."
    rm -f /tmp/${libxml2_filename}.tar.gz
    rm -fr /tmp/${libxml2_filename}
}

_install_curl(){
    cd /tmp
    _info "${curl_filename} install start..."
    rm -fr ${curl_filename}
    DownloadFile "${curl_filename}.tar.gz" "${curl_download_url}"
    tar zxf ${curl_filename}.tar.gz
    cd ${curl_filename}
    CheckError "./configure --prefix=${curl102_location} --with-ssl=${openssl102_location}"
    CheckError "parallel_make"
    CheckError "make install"
    AddToEnv "${curl102_location}"
    CreateLib64Dir "${curl102_location}"
    _success "${curl_filename} install completed..."
    rm -f /tmp/${curl_filename}.tar.gz
    rm -fr /tmp/${curl_filename}
}

_install_pcre(){
    cd /tmp
    _info "${pcre_filename} install start..."
    rm -fr ${pcre_filename}
    DownloadFile "${pcre_filename}.tar.gz" "${pcre_download_url}"
    tar zxf ${pcre_filename}.tar.gz
    cd ${pcre_filename}
    CheckError "./configure --prefix=${pcre_location}"
    CheckError "parallel_make"
    CheckError "make install"
    AddToEnv "${pcre_location}"
    CreateLib64Dir "${pcre_location}"
    if ! grep -qE "^${pcre_location}/lib" /etc/ld.so.conf.d/*.conf; then
        echo "${pcre_location}/lib" > /etc/ld.so.conf.d/pcre.conf
    fi
    ldconfig
    _success "${pcre_filename} install completed..."
    rm -f /tmp/${pcre_filename}.tar.gz
    rm -fr /tmp/${pcre_filename}
}

_install_openssl102(){
    cd /tmp
    _info "${openssl102_filename} install start..."
    rm -fr ${openssl102_filename}
    DownloadFile "${openssl102_filename}.tar.gz" "${openssl102_download_url}"
    tar zxf ${openssl102_filename}.tar.gz
    cd ${openssl102_filename}
    CheckError "./config --prefix=${openssl102_location} --openssldir=${openssl102_location} -fPIC shared zlib"
    CheckError "parallel_make"
    CheckError "make install"

    #Debian8
    if Is64bit; then
        if [ -f /usr/lib/x86_64-linux-gnu/libssl.so.1.0.0 ]; then
            ln -sf ${openssl102_location}/lib/libssl.so.1.0.0 /usr/lib/x86_64-linux-gnu
        fi
        if [ -f /usr/lib/x86_64-linux-gnu/libcrypto.so.1.0.0 ]; then
            ln -sf ${openssl102_location}/lib/libcrypto.so.1.0.0 /usr/lib/x86_64-linux-gnu
        fi
    else
        if [ -f /usr/lib/i386-linux-gnu/libssl.so.1.0.0 ]; then
            ln -sf ${openssl102_location}/lib/libssl.so.1.0.0 /usr/lib/i386-linux-gnu
        fi
        if [ -f /usr/lib/i386-linux-gnu/libcrypto.so.1.0.0 ]; then
            ln -sf ${openssl102_location}/lib/libcrypto.so.1.0.0 /usr/lib/i386-linux-gnu
        fi
    fi

    AddToEnv "${openssl102_location}"
    CreateLib64Dir "${openssl102_location}"
    export PKG_CONFIG_PATH=${openssl102_location}/lib/pkgconfig:$PKG_CONFIG_PATH
    if ! grep -qE "^${openssl102_location}/lib" /etc/ld.so.conf.d/*.conf; then
        echo "${openssl102_location}/lib" > /etc/ld.so.conf.d/openssl102.conf
    fi
    ldconfig

    _success "${openssl102_filename} install completed..."
    rm -f /tmp/${openssl102_filename}.tar.gz
    rm -fr /tmp/${openssl102_filename}
}

_install_nghttp2(){
    cd /tmp
    _info "${nghttp2_filename} install start..."
    rm -fr ${nghttp2_filename}
    DownloadFile "${nghttp2_filename}.tar.gz" "${nghttp2_download_url}"
    tar zxf ${nghttp2_filename}.tar.gz
    cd ${nghttp2_filename}
    if [ -d "${openssl102_location}" ]; then
        export OPENSSL_CFLAGS="-I${openssl102_location}/include"
        export OPENSSL_LIBS="-L${openssl102_location}/lib -lssl -lcrypto"
    fi
    CheckError "./configure --prefix=${nghttp2_location} --enable-lib-only"
    CheckError "parallel_make"
    CheckError "make install"
    unset OPENSSL_CFLAGS OPENSSL_LIBS
    AddToEnv "${nghttp2_location}"
    CreateLib64Dir "${nghttp2_location}"
    if ! grep -qE "^${nghttp2_location}/lib" /etc/ld.so.conf.d/*.conf; then
        echo "${nghttp2_location}/lib" > /etc/ld.so.conf.d/nghttp2.conf
    fi
    ldconfig
    _success "${nghttp2_filename} install completed..."
    rm -f /tmp/${nghttp2_filename}.tar.gz
    rm -fr /tmp/${nghttp2_filename}
}

_create_logrotate_file(){
    # 定期清理日志
    cat > apache-logs <<EOF
${apache_location}/logs/*.log {
    daily
    rotate 30
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        [ ! -f ${apache_location}/logs/httpd.pid ] || kill -USR1 \`cat ${apache_location}/logs/httpd.pid\`
    endscript
}
EOF
    cat > apache-wwwlogs <<EOF
${var}/default/wwwlogs/*.log {
    daily
    rotate 30
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        [ ! -f ${apache_location}/logs/httpd.pid ] || kill -USR1 \`cat ${apache_location}/logs/httpd.pid\`
    endscript
}

${var}/default/wwwlogs/apache/*.log {
    daily
    rotate 30
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        [ ! -f ${apache_location}/logs/httpd.pid ] || kill -USR1 \`cat ${apache_location}/logs/httpd.pid\`
    endscript
}

${var}/wwwlogs/*.log {
    daily
    rotate 30
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        [ ! -f ${apache_location}/logs/httpd.pid ] || kill -USR1 \`cat ${apache_location}/logs/httpd.pid\`
    endscript
}
EOF
}

_create_sysv_script(){
    cat > httpd <<'EOF'
#!/bin/bash
# chkconfig: 2345 55 25
# description: apache service script

### BEGIN INIT INFO
# Provides:          httpd
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: apache
# Description:       apache service script
### END INIT INFO

prefix={apache_location}

NAME=httpd
PID_FILE=$prefix/logs/$NAME.pid
BIN=$prefix/bin/$NAME
CONFIG_FILE=$prefix/conf/$NAME.conf
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:{openssl_location_lib}

start()
{
    echo -n "Starting $NAME..."
    if [ -f $PID_FILE ];then
        mPID=`cat $PID_FILE`
        isRunning=`ps ax | awk '{ print $1 }' | grep -e "^${mPID}$"`
        if [ "$isRunning" != '' ];then
            echo "$NAME (pid `pidof $NAME`) already running."
            exit 1
        fi
    fi
    $BIN -k start
    if [ "$?" != 0 ] ; then
        echo " failed"
        exit 1
    else
        echo " done"
    fi
}

stop()
{
    echo -n "Stoping $NAME... "
    if [ -f $PID_FILE ];then
        mPID=`cat $PID_FILE`
        isRunning=`ps ax | awk '{ print $1 }' | grep -e "^${mPID}$"`
        if [ "$isRunning" = '' ];then
            echo "$NAME is not running."
            exit 1
        fi
    else
        echo "PID file found, $NAME is not running ?"
        exit 1
    fi
    $BIN -k stop
    if [ "$?" != 0 ] ; then
        echo " failed"
        exit 1
    else
        echo " done"
    fi
}

restart(){
    echo -n "Restarting $NAME..."
    $BIN -k restart
    if [ "$?" != 0 ] ; then
        echo " failed"
        exit 1
    else
        echo " done"
    fi
}

reload() {
    echo -n "Reload service $NAME... "
    if [ -f $PID_FILE ];then
        mPID=`cat $PID_FILE`
        isRunning=`ps ax | awk '{ print $1 }' | grep -e "^${mPID}$"`
        if [ "$isRunning" != '' ];then
            $BIN -k graceful
            echo " done"
        else
            echo "$NAME is not running, can't reload."
            exit 1
        fi
    else
        echo "$NAME is not running, can't reload."
        exit 1
    fi
}

status(){
    if [ -f $PID_FILE ];then
        mPID=`cat $PID_FILE`
        isRunning=`ps ax | awk '{ print $1 }' | grep -e "^${mPID}$"`
        if [ "$isRunning" != '' ];then
            echo "$NAME (pid `pidof $NAME`) is running."
            exit 0
        else
            echo "$NAME already stopped."
            exit 1
        fi
    else
        echo "$NAME already stopped."
        exit 1
    fi
}

configtest() {
    echo "Test $NAME configure files... "
    $BIN -t
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    reload)
        reload
        ;;
    test)
        configtest
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|status|test}"
esac
EOF
    sed -i "s|^prefix={apache_location}$|prefix=${apache_location}|g" httpd
    sed -i "s|{openssl102_location_lib}|${openssl102_location}/lib|g" httpd
}

_create_spec(){
    cat > ~/rpmbuild/SPECS/apache2441.spec << EOF
Name:           hws-httpd
Version:        2.4.41
Release:        1%{?dist}
Summary:        Apache Http Server

Group:          Applications/Internet
License:        GPLv3+
URL:            https://www.hws.com
Packager:       hws
Source0:        ${apr_filename}.tar.gz
Source1:        ${apr_util_filename}.tar.gz
Source2:        ${apache2441_filename}.tar.gz

BuildRoot:      %_topdir/BUILDROOT
BuildRequires:  gcc,make
Requires:       python2-devel,expat-devel,zlib-devel

%description
Apache Http Server build for hws

%prep
tar zxf \$RPM_SOURCE_DIR/${apr_filename}.tar.gz
tar zxf \$RPM_SOURCE_DIR/${apr_util_filename}.tar.gz
tar zxf \$RPM_SOURCE_DIR/${apache2441_filename}.tar.gz

%build
LDFLAGS=-ldl
cd ${apache2441_filename}
mv \$RPM_BUILD_DIR/${apr_filename} srclib/apr
mv \$RPM_BUILD_DIR/${apr_util_filename} srclib/apr-util
./configure --prefix=${apache_location} \
--bindir=${apache_location}/bin \
--sbindir=${apache_location}/bin \
--sysconfdir=${apache_location}/conf \
--libexecdir=${apache_location}/modules \
--with-pcre=${pcre_location} \
--with-ssl=${openssl102_location} \
--with-nghttp2=${nghttp2_location} \
--with-libxml2=${libxml2_location} \
--with-curl=${curl102_location} \
--with-mpm=event \
--with-included-apr \
--enable-modules=reallyall \
--enable-mods-shared=reallyall
unset LDFLAGS

make %{?_smp_mflags}

%install
cd ${apache2441_filename}
make install DESTDIR=%{buildroot}
install -D -m 0755 \$RPM_SOURCE_DIR/httpd \$RPM_BUILD_ROOT/etc/init.d/httpd
install -D -m 0644 \$RPM_SOURCE_DIR/apache-logs \$RPM_BUILD_ROOT/etc/logrotate.d/apache-logs
install -D -m 0644 \$RPM_SOURCE_DIR/apache-wwwlogs \$RPM_BUILD_ROOT/etc/logrotate.d/apache-wwwlogs

%post
[ $? -ne 0 ] && useradd -M -U www -d /home/www -s /sbin/nologin
chkconfig --add httpd >/dev/null 2>&1
/etc/init.d/httpd start

%preun
chkconfig --del httpd >/dev/null 2>&1
/etc/init.d/httpd stop

%files
${apache_location}
/etc/init.d/httpd
/etc/logrotate.d/apache-logs
/etc/logrotate.d/apache-wwwlogs

%doc

%clean
rm -fr %{buildroot}

EOF
}

rpmbuild_apache2441(){
    apache_location=/hws.com/hwsmaster/server/apache-2_4_41
    _install_apache_depend
    mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    cd ~/rpmbuild/SOURCES
    _info "Downloading and Extracting ${apr_filename} files..."
    DownloadFile "${apr_filename}.tar.gz" ${apr_download_url}
    _info "Downloading and Extracting ${apr_util_filename} files..."
    DownloadFile "${apr_util_filename}.tar.gz" ${apr_util_download_url}
    _info "Downloading and Extracting ${apache2441_filename} files..."
    DownloadFile "${apache2441_filename}.tar.gz" ${apache2441_download_url}
    _create_logrotate_file
    _create_sysv_script
    _create_spec
    rpmbuild -bb ~/rpmbuild/SPECS/apache2441.spec
}

main() {
    include config
    include public
    load_config
    IsRoot
    InstallPreSetting
    rpmbuild_apache2441
}
main "$@" |tee /tmp/install.log
