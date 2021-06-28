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

_install_nginx_depend(){
    _info "Starting to install dependencies packages for Nginx..."
    if [ "${PM}" = "yum" ];then
        local yum_depends=(zlib-devel)
        for depend in ${yum_depends[@]}
        do
            InstallPack "yum -y install ${depend}"
        done
    elif [ "${PM}" = "apt-get" ];then
        local apt_depends=(zlib1g-dev)
        for depend in ${apt_depends[@]}
        do
            InstallPack "apt-get -y install ${depend}"
        done
    fi
    id -u www >/dev/null 2>&1
    [ $? -ne 0 ] && useradd -M -U www -r -d /dev/null -s /sbin/nologin
    mkdir -p ${nginx_location}
    _success "Install dependencies packages for Nginx completed..."
}

_create_logrotate_file() {
    cat > nginx-logs <<EOF
${nginx_location}/var/log/*.log {
    daily
    rotate 30
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        [ ! -f ${nginx_location}/var/run/nginx.pid ] || kill -USR1 \`cat ${nginx_location}/var/run/nginx.pid\`
    endscript
}
EOF

    cat > nginx-wwwlogs <<EOF
${var}/default/wwwlogs/*.log {
    daily
    rotate 30
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        [ ! -f ${nginx_location}/var/run/nginx.pid ] || kill -USR1 \`cat ${nginx_location}/var/run/nginx.pid\`
    endscript
}

${var}/default/wwwlogs/nginx/*.log {
    daily
    rotate 30
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        [ ! -f ${nginx_location}/var/run/nginx.pid ] || kill -USR1 \`cat ${nginx_location}/var/run/nginx.pid\`
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
        [ ! -f ${nginx_location}/var/run/nginx.pid ] || kill -USR1 \`cat ${nginx_location}/var/run/nginx.pid\`
    endscript
}
EOF
}

_create_sysv_script() {
    cat > nginx <<'EOF'
#!/bin/bash
# chkconfig: 2345 55 25
# description: nginx service script

### BEGIN INIT INFO
# Provides:          nginx
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: nginx
# Description:       nginx service script
### END INIT INFO

prefix=/hws.com/hwsmaster/server/nginx-1_18_0

NAME=nginx
PID_FILE=$prefix/var/run/$NAME.pid
BIN=$prefix/sbin/$NAME
CONFIG_FILE=$prefix/etc/$NAME.conf

ulimit -n 10240
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
    $BIN -c $CONFIG_FILE
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
    $BIN -s stop
    if [ "$?" != 0 ] ; then
        echo " failed"
        exit 1
    else
        echo " done"
    fi
}

restart(){
    $0 stop
    sleep 1
    $0 start
}

reload() {
    echo -n "Reload service $NAME... "
    if [ -f $PID_FILE ];then
        mPID=`cat $PID_FILE`
        isRunning=`ps ax | awk '{ print $1 }' | grep -e "^${mPID}$"`
        if [ "$isRunning" != '' ];then
            $BIN -s reload
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
}

_create_spec(){
    cat > ~/rpmbuild/SPECS/nginx118.spec << EOF
Name:           nginx
Version:        1.18.0
Release:        1%{?dist}
Summary:        Nginx Server

Group:          Applications/Internet
License:        GPLv3+
URL:            https://www.hws.com
Packager:       hws
Source0:        ${pcre_filename}.tar.gz
Source1:        ${openssl102_filename}.tar.gz
Source2:        ${nginx118_filename}.tar.gz

BuildRoot:      %_topdir/BUILDROOT
BuildRequires:  gcc,make
Requires:       zlib-devel

%description
Nginx Server build for hws

%prep
tar zxf \$RPM_SOURCE_DIR/${pcre_filename}.tar.gz
tar zxf \$RPM_SOURCE_DIR/${openssl102_filename}.tar.gz
tar zxf \$RPM_SOURCE_DIR/${nginx118_filename}.tar.gz

%build
cd ${nginx118_filename}
./configure --prefix=${nginx_location} \
--conf-path=${nginx_location}/etc/nginx.conf \
--error-log-path=${nginx_location}/var/log/error.log \
--pid-path=${nginx_location}/var/run/nginx.pid \
--lock-path=${nginx_location}/var/lock/nginx.lock \
--http-log-path=${nginx_location}/var/log/access.log \
--http-client-body-temp-path=${nginx_location}/var/tmp/client \
--http-proxy-temp-path=${nginx_location}/var/tmp/proxy \
--http-fastcgi-temp-path=${nginx_location}/var/tmp/fastcgi \
--http-uwsgi-temp-path=${nginx_location}/var/tmp/uwsgi \
--http-scgi-temp-path=${nginx_location}/var/tmp/scgi \
--with-pcre=\$RPM_BUILD_DIR/${pcre_filename} \
--with-openssl=\$RPM_BUILD_DIR/${openssl102_filename} \
--user=www \
--group=www \
--with-stream \
--with-threads \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gzip_static_module \
--with-http_realip_module \
--with-http_stub_status_module

make %{?_smp_mflags}

%install
cd ${nginx118_filename}
make install DESTDIR=%{buildroot}
install -D -m 0755 \$RPM_SOURCE_DIR/nginx \$RPM_BUILD_ROOT/etc/init.d/nginx
install -D -m 0644 \$RPM_SOURCE_DIR/nginx-logs \$RPM_BUILD_ROOT/etc/logrotate.d/nginx-logs
install -D -m 0644 \$RPM_SOURCE_DIR/nginx-wwwlogs \$RPM_BUILD_ROOT/etc/logrotate.d/nginx-wwwlogs

%post
mkdir -p ${nginx_location}/var/{log,run,lock,tmp}
mkdir -p ${nginx_location}/var/tmp/{client,proxy,fastcgi,uwsgi}
mkdir -p ${nginx_location}/etc/vhost
useradd -M -U www -r -d /dev/null -s /sbin/nologin >/dev/null 2>&1
chkconfig --add nginx >/dev/null 2>&1
/etc/init.d/nginx start

%preun
chkconfig --del nginx >/dev/null 2>&1
/etc/init.d/nginx stop

%files
${nginx_location}/etc/fastcgi.conf
${nginx_location}/etc/fastcgi.conf.default
${nginx_location}/etc/fastcgi_params
${nginx_location}/etc/fastcgi_params.default
${nginx_location}/etc/koi-utf
${nginx_location}/etc/koi-win
${nginx_location}/etc/mime.types
${nginx_location}/etc/mime.types.default
${nginx_location}/etc/nginx.conf
${nginx_location}/etc/nginx.conf.default
${nginx_location}/etc/scgi_params
${nginx_location}/etc/scgi_params.default
${nginx_location}/etc/uwsgi_params
${nginx_location}/etc/uwsgi_params.default
${nginx_location}/etc/win-utf
${nginx_location}/html/50x.html
${nginx_location}/html/index.html
${nginx_location}/sbin/nginx
/etc/init.d/nginx
/etc/logrotate.d/nginx-logs
/etc/logrotate.d/nginx-wwwlogs


%doc

%clean
rm -fr %{buildroot}

EOF
}

rpmbuild_nginx118(){
    nginx_location=/hws.com/hwsmaster/server/nginx-1_18_0 # 如果要改变包的安装路径,改这个就行
    _install_nginx_depend
    mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    cd ~/rpmbuild/SOURCES
    _info "Downloading and Extracting ${pcre_filename} files..."
    DownloadFile "${pcre_filename}.tar.gz" ${pcre_download_url}
    _info "Downloading and Extracting ${openssl102_filename} files..."
    DownloadFile "${openssl102_filename}.tar.gz" ${openssl102_download_url}
    _info "Downloading and Extracting ${nginx118_filename} files..."
    DownloadFile "${nginx118_filename}.tar.gz" ${nginx118_download_url}
    _create_logrotate_file
    _create_sysv_script
    _create_spec
    rpmbuild -bb ~/rpmbuild/SPECS/nginx118.spec
}

main() {
    include config
    include public
    load_config
    IsRoot
    InstallPreSetting
    rpmbuild_nginx118
}
main "$@" |tee /tmp/install.log
