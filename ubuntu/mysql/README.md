# MySQL

The following assumes you have an fresh install of Ubuntu 12.x and you are logged in via ssh.

Most of the following commands will require root permissions, so use `sudo` where appropriate.

## Update & upgrade

```
apt-get update
apt-get upgrade
```

## Set timezone (interactive)

`dpkg-reconfigure tzdata`

## Sync the clock

`ntpdate ntp.ubuntu.com`

## Add new user, and add to sudoers file
```
adduser foo
adduser foo sudo
```

## Configure hosts file

/etc/hosts

```
127.0.0.1       localhost localhost.localdomain

95.123.456.789  mysql-01.domain.com mysql-01
10.123.456.7    mysql-01.domain.com mysql-01
```

## Check hostname

`hostname` should give short name, mysql-01. `hostname -f` should give FQDN `mysql-01.domain.com`.

## Firewall

`ufw status` will show firewall is <strong>not</strong> enabled.

Set the default rule as deny with `ufw default deny` then add our rules to allow connections:

```
ufw allow ssh
ufw allow from 10.123.4.567 to any port 3306
```

To allow ssh from only a specific IP (recommended) use `ufw allow from 85.123.432.22 to any port 22` instead.

Turn on the firewall: `ufw disable && ufw enable` and confirm with `ufw status`.

## Package

`apt-get install mysql-server`

## BindAddress

This server is intended to be a stand-alone MySQl server, and by default only localhost can connect. To change this, edit the `/etc/mysql/my.cnf` file comment out the folloing line:

```
#
# Instead of skip-networking the default is now to listen only on
# localhost which is more compatible and is not less secure.
#bind-address           = 127.0.0.1
```

## Charset

It seems some charsets do not default to UTF8, no idea why. But we can set these in `my.cnf`

```
[mysqld]

collation-server = utf8_unicode_ci
init-connect='SET NAMES utf8'
character-set-server = utf8
```

After a restart, check these with `SHOW variables LIKE 'char%'` and `SHOW variables LIKE 'collation%'`

## Users

Add any users we require for remote connections. Remember the following!

<blockquote>MySQL permits one extra connection on top of the max_connections limit which is reserved for the database user having SUPER privilege in order to diagnose connection problems. Normally the administrator user has this SUPER privilege. You should avoid granting SUPER privilege to app users.</blockquote>

```
CREATE USER 'foo'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'foo'@'%' WITH GRANT OPTION;
```

Verify users priviledges with `SHOW GRANTS FOR 'foo'@'%';` and use `FLUSH PRIVILEGES;` if nothing appears / update changes.

The `%` allows from <strong>any</strong> host, although we have a firewall it's safer to set this to a specific host/ip

## Basic MySQL tuning

### innodb_buffer_pool_size

Regardless of the resources availble, MySQL will only use `128M` of for its `innodb_buffer_pool_size` this is possibly the most basic of changes to make which will radically improve performace.

If this server is only going to be used for MySQL, allowing for 60%-70% of the free memory to be used is a good start, but you can change this later as per your requirements.

/etc/mysql/my.cnf

```
#
# * InnoDB
#
# InnoDB is enabled by default with a 10MB datafile in /var/lib/mysql/.
# Read the manual for more InnoDB related options. There are many!
#
innodb_buffer_pool_size=1024M
```

Allow MySQL to use some more memory (than the defaults) for its query cache, e.g: 

```
query_cache_limit       = 8M
query_cache_size        = 128M
```

Restart MySQL and you will now see the changes with `SHOW variables LIKE 'inno%'` etc.

### max_connections

To see the settings of the current setup, or the existing server, the following queries are useful:

Show current setting: `show variables like "max_connections";`

Show total number of current connections : `show status like 'Conn%';`

Show the acitve MySQL users and their status: `SHOW FULL PROCESSLIST;`

From MySQL:

<blockquote>The maximum number of connections MySQL can support depends on the quality of the thread library on a given platform, the amount of RAM available, how much RAM is used for each connection, the workload from each connection, and the desired response time. <br/><br/>Linux or Solaris should be able to support at 500 to 1000 simultaneous connections routinely and as many as 10,000 connections if you have many gigabytes of RAM available and the workload from each is low or the response time target undemanding.</blockquote>

## Basic OS tuning

Some fundamental settings when running a standalone MySQL server on Linux

### Filesystem

Reference http://www.mysqlperformanceblog.com/2009/01/30/linux-schedulers-in-tpcc-like-benchmark/

* ext4 (or xfs), mount with noatime
* Scheduler – use deadline or noop

```shell
# echo deadline >/sys/block/sda/queue/scheduler
add "elevator=deadline" to grub.conf
```

### Memory

Reference http://www.mysqlperformanceblog.com/2013/12/07/linux-performance-tuning-tips-mysql/

* Swappiness

```shell
# echo 0 > /proc/sys/vm/swappiness
add "vm.swappiness = 0" to /etc/sysctl.conf
```

* NUMA. Set numa interleave all

```shell
numactl --interleave=all
```

### CPU

Make sure there is no powersave mode enabled. Check `/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` and make sure it is not `ondemand`.

Check `/proc/cpuinfo` and compare cpu MHz number to what is listed under the "model name". Disable the "ondemand" if it is running.

```shell
$ ps ax| grep kondemand|wc -l 
65 

$ cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 
ondemand
```

Does the MHz match the CPU's modelname fequency? 	

```shell
/proc/cpuinfo: model name : Intel(R) Xeon(R) CPU E5-4640 0 @ 2.40GHz

cpu MHz : 1200.000
```

In this case we will need to disable "ondemand".
