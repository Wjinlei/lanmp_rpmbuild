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

_create_sysv_script() {
    cat > redis << 'EOF'
#!/bin/bash
# chkconfig: 2345 55 25
# description: redis service script

### BEGIN INIT INFO
# Provides:          redis
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: redis
# Description:       redis service script
### END INIT INFO

prefix={redis_location}

NAME=redis-server
BIN=$prefix/bin/$NAME
PID_FILE=$prefix/var/run/redis.pid
CONFIG_FILE=$prefix/etc/redis.conf

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
    kill -TERM `cat $PID_FILE`
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
    *)
        echo "Usage: $0 {start|stop|restart|status|reload}"
esac
EOF
    sed -i "s|^prefix={redis_location}$|prefix=${redis_location}|g" redis
}

_create_spec(){
    cat > ~/rpmbuild/SPECS/redis506.spec << EOF
Name:           redis
Version:        5.0.6
Release:        1%{?dist}
Summary:        redis 5.0.6

Group:          Applications/Internet
License:        GPLv3+
URL:            https://www.hws.com
Packager:       hws
Source0:        ${redis506_filename}.tar.gz

BuildRoot:      %_topdir/BUILDROOT
BuildRequires:  gcc,make

%description
redis 5.0.6 build for hws.com

%prep
tar zxf \$RPM_SOURCE_DIR/${redis506_filename}.tar.gz

%build
cd ${redis506_filename}
if [ $(getconf WORD_BIT) = '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    sed -i '1i\CFLAGS= -march=i686' src/Makefile && sed -i 's@^OPT=.*@OPT=-O2 -march=i686@' src/.make-settings
fi

make %{?_smp_mflags}

%install
cd ${redis506_filename}
install -D -m 0755 \$RPM_SOURCE_DIR/redis \$RPM_BUILD_ROOT/etc/init.d/redis
install -D -m 0755 src/redis-benchmark \$RPM_BUILD_ROOT/${redis_location}/bin/redis-benchmark
install -D -m 0755 src/redis-check-aof \$RPM_BUILD_ROOT/${redis_location}/bin/redis-check-aof
install -D -m 0755 src/redis-check-rdb \$RPM_BUILD_ROOT/${redis_location}/bin/redis-check-rdb
install -D -m 0755 src/redis-cli \$RPM_BUILD_ROOT/${redis_location}/bin/redis-cli
install -D -m 0755 src/redis-sentinel \$RPM_BUILD_ROOT/${redis_location}/bin/redis-sentinel
install -D -m 0755 src/redis-server \$RPM_BUILD_ROOT/${redis_location}/bin/redis-server
install -D -m 0644 redis.conf \$RPM_BUILD_ROOT/${redis_location}/etc/redis.conf
install -D -m 0644 \$RPM_SOURCE_DIR/README.log \$RPM_BUILD_ROOT/${redis_location}/var/log/README.log
install -D -m 0644 \$RPM_SOURCE_DIR/README.run \$RPM_BUILD_ROOT/${redis_location}/var/run/README.run

%post
sed -i "s@pidfile.*@pidfile ${redis_location}/var/run/redis.pid@" ${redis_location}/etc/redis.conf
sed -i "s@logfile.*@logfile ${redis_location}/var/log/redis.log@" ${redis_location}/etc/redis.conf
sed -i "s@^dir.*@dir ${redis_location}/var@" ${redis_location}/etc/redis.conf
sed -i 's@daemonize no@daemonize yes@' ${redis_location}/etc/redis.conf
sed -i "s@port 6379@port ${redis_port}@" ${redis_location}/etc/redis.conf
sed -i "s@^# bind 127.0.0.1@bind 127.0.0.1@" ${redis_location}/etc/redis.conf
chkconfig --add redis >/dev/null 2>&1
/etc/init.d/redis start

%preun
chkconfig --del redis >/dev/null 2>&1
/etc/init.d/redis stop

%files
${redis_location}
/etc/init.d/redis

%doc

%clean
rm -fr %{buildroot}

EOF
}

rpmbuild_redis506(){
    redis_port=6379
    redis_location=/hws.com/hwsmaster/server/redis5_0_6
    mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    cd ~/rpmbuild/SOURCES
    DownloadFile "${redis506_filename}.tar.gz" "${redis506_download_url}"
    echo "This is log directory" > README.log
    echo "This is run directory" > README.run
    _create_sysv_script
    _create_spec
    rpmbuild -bb ~/rpmbuild/SPECS/redis506.spec
}

main() {
    include config
    include public
    load_config
    IsRoot
    InstallPreSetting
    rpmbuild_redis506
}
main "$@" |tee /tmp/install.log
