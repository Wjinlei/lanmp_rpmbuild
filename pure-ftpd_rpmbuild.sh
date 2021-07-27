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

_install_pureftpd_depends(){
    _info "Starting to install dependencies packages for Pureftpd..."
    if [ "${PM}" = "yum" ];then
        local yum_depends=(openssl-devel zlib-devel)
        for depend in ${yum_depends[@]}
        do
            InstallPack "yum -y install ${depend}"
        done
    elif [ "${PM}" = "apt-get" ];then
        local apt_depends=(libssl-dev zlib1g-dev)
        for depend in ${apt_depends[@]}
        do
            InstallPack "apt -y install ${depend}"
        done
    fi
    id -u www >/dev/null 2>&1
    [ $? -ne 0 ] && useradd -M -U www -d /home/www -s /sbin/nologin
    mkdir -p ${pureftpd_location}
    _success "Install dependencies packages for Pureftpd completed..."
}

_create_pureftpd_config(){
    cat > pure-ftpd.conf <<EOF
# default 21
Bind 0.0.0.0,${ftp_port}

# default yes
ChrootEveryone yes

# default no
BrokenClientsCompatibility no

# default 50
MaxClientsNumber 50

# default yes
Daemonize yes

# default 8
MaxClientsPerIP 10

# default no
VerboseLog no

# default yes
DisplayDotFiles yes

# default no
AnonymousOnly no

# default no
NoAnonymous yes

# default ftp
SyslogFacility ftp

# default yes
DontResolve yes

# default 15
MaxIdleTime 15

# default /etc/pureftpd.pdb
PureDB ${pureftpd_location}/etc/pureftpd.pdb

# default yes
UnixAuthentication yes

# default 10000 8
LimitRecursion 9999999999 8

# default no
AnonymousCanCreateDirs no

# default 4
MaxLoad 4

# default 30000 50000
PassivePortRange 55000 56000

# default yes
AntiWarez yes

# default 133:022
Umask 133:022

# default 100
MinUID 100

# default no
AllowUserFXP no

# default no
AllowAnonymousFXP no

# default no
ProhibitDotFilesWrite no

# default no
ProhibitDotFilesRead no

# default no
AutoRename no

# default no
AnonymousCantUpload no

# default yes
CreateHomeDir no

# default /var/run/pure-ftpd.pid
PIDFile ${pureftpd_location}/var/run/pure-ftpd.pid

# default 99
MaxDiskUsage 99

# default yes
CustomerProof yes

# default 1
TLS 1
EOF
}

_create_sysv_script(){
    cat > pure-ftpd << 'EOF'
#!/bin/bash
# chkconfig: 2345 55 25
# description: pure-ftpd service script

### BEGIN INIT INFO
# Provides:          pure-ftpd
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: pure-ftpd
# Description:       pure-ftpd service script
### END INIT INFO

prefix={pureftpd_location}

NAME=pure-ftpd
BIN=$prefix/sbin/$NAME
PID_FILE=$prefix/var/run/$NAME.pid
CONFIG_FILE=$prefix/etc/$NAME.conf

wait_for_pid () {
    try=0
    while test $try -lt 35 ; do
        case "$1" in
            'created')
            if [ -f "$2" ] ; then
                try=''
                break
            fi
            ;;
            'removed')
            if [ ! -f "$2" ] ; then
                try=''
                break
            fi
            ;;
        esac
        echo -n .
        try=`expr $try + 1`
        sleep 1
    done
}

start()
{
    echo -n "Starting $NAME..."
    if [ -f $PID_FILE ];then
        mPID=`cat $PID_FILE`
        isRunning=`ps ax | awk '{ print $1 }' | grep -e "^${mPID}$"`
        if [ "$isRunning" != '' ];then
            echo "$NAME (pid $mPID) already running."
            exit 1
        fi
    fi
    $BIN $CONFIG_FILE
    if [ "$?" != 0 ] ; then
        echo " failed"
        exit 1
    fi
    wait_for_pid created $PID_FILE
    if [ -n "$try" ] ; then
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
    kill -QUIT `cat $PID_FILE`
    wait_for_pid removed $PID_FILE
    if [ -n "$try" ] ; then
        echo " failed"
        exit 1
    else
        echo " done"
    fi
}

restart(){
    $0 stop
    $0 start
}

reload() {
    echo -n "Reload service $NAME... "
    if [ -f $PID_FILE ];then
        mPID=`cat $PID_FILE`
        isRunning=`ps ax | awk '{ print $1 }' | grep -e "^${mPID}$"`
        if [ "$isRunning" != '' ];then
            kill -USR2 `cat $PID_FILE`
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
            echo "$NAME (pid $mPID) is running."
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

force-stop() {
    echo -n "force-stop $NAME "
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
    kill -TERM `cat $PID_FILE`
    wait_for_pid removed $PID_FILE
    if [ -n "$try" ] ; then
        echo " failed"
        exit 1
    else
        echo " done"
    fi
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
    force-stop)
        force-stop
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|status|force-stop}"
esac
EOF
    sed -i "s|^prefix={pureftpd_location}$|prefix=${pureftpd_location}|g" pure-ftpd
}

_create_spec(){
    cat > ~/rpmbuild/SPECS/pure-ftpd.spec << EOF
Name:           hws-pureftpd
Version:        1.0.49
Release:        1%{?dist}
Summary:        pure-ftpd 1.0.49

Group:          Applications/Internet
License:        GPLv3+
URL:            https://www.hws.com
Packager:       hws
Source0:        ${pureftpd_filename}.tar.gz

BuildRoot:      %_topdir/BUILDROOT
BuildRequires:  gcc,make
Requires:       openssl-devel,zlib-devel

%description
pure-ftpd 1.0.49 build for hws.com

%prep
tar zxf \$RPM_SOURCE_DIR/${pureftpd_filename}.tar.gz

%build
cd ${pureftpd_filename}
./configure --prefix=${pureftpd_location} \
--with-puredb \
--with-quotas \
--with-cookie \
--with-virtualhosts \
--with-diraliases \
--with-sysquotas \
--with-ratios \
--with-altlog \
--with-paranoidmsg \
--with-shadow \
--with-welcomemsg \
--with-throttling \
--with-uploadscript \
--with-language=english \
--with-ftpwho \
--with-tls

make %{?_smp_mflags}

%install
cd ${pureftpd_filename}
make install DESTDIR=%{buildroot}
install -D -m 0755 \$RPM_SOURCE_DIR/pure-ftpd \$RPM_BUILD_ROOT/etc/init.d/pure-ftpd
install -D -m 0644 \$RPM_SOURCE_DIR/pure-ftpd.conf \$RPM_BUILD_ROOT/${pureftpd_location}/etc/pure-ftpd.conf
install -D -m 0600 \$RPM_SOURCE_DIR/pureftpd.passwd \$RPM_BUILD_ROOT/${pureftpd_location}/etc/pureftpd.passwd
install -D -m 0600 \$RPM_SOURCE_DIR/pureftpd.pdb \$RPM_BUILD_ROOT/${pureftpd_location}/etc/pureftpd.pdb
install -D -m 0600 \$RPM_SOURCE_DIR/pure-ftpd.pem \$RPM_BUILD_ROOT/etc/ssl/private/pure-ftpd.pem
install -D -m 0644 \$RPM_SOURCE_DIR/README \$RPM_BUILD_ROOT/${pureftpd_location}/var/run/README

%post
id -u www >/dev/null 2>&1
[ $? -ne 0 ] && useradd -M -U www -d /home/www -s /sbin/nologin
chkconfig --add pure-ftpd >/dev/null 2>&1
[ $? -ne 0 ] && echo "[ERROR]: chkconfig --add pure-ftpd"
/etc/init.d/pure-ftpd start
exit 0

%preun
/etc/init.d/pure-ftpd stop >/dev/null 2>&1
chkconfig --del pure-ftpd >/dev/null 2>&1
exit 0

%files
${pureftpd_location}
/etc/init.d/pure-ftpd
/etc/ssl/private/pure-ftpd.pem

%doc

%clean
rm -fr %{buildroot}

EOF
}

rpmbuild_pure-ftpd(){
    ftp_port=21
    pureftpd_location=/hws.com/hwsmaster/server/pureftpd1_0_49
    _install_pureftpd_depends
    mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    cd ~/rpmbuild/SOURCES
    _info "Downloading and Extracting ${pureftpd_filename} files..."
    DownloadFile "${pureftpd_filename}.tar.gz" ${pureftpd_download_url}
    touch pureftpd.passwd
    touch pureftpd.pdb
    echo "This is hws build pure-ftpd pid directory" > README
    openssl rand -writerand ~/.rnd >/dev/null 2>&1
    openssl req -x509 -nodes -subj /C=CN/ST=Sichuan/L=Chengdu/O=HWS-LINUXMASTER/OU=HWS/CN=127.0.0.1/emailAddress=admin@hws.com -days 3560 -newkey rsa:2048 -keyout pure-ftpd.pem -out pure-ftpd.pem
    _create_pureftpd_config
    _create_sysv_script
    _create_spec
    rpmbuild -bb ~/rpmbuild/SPECS/pure-ftpd.spec
}

main() {
    include config
    include public
    load_config
    IsRoot
    InstallPreSetting
    rpmbuild_pure-ftpd
}
main "$@" |tee /tmp/install.log
