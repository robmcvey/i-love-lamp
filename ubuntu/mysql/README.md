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

max_allowed_packet=64M
collation-server = utf8_unicode_ci
init-connect='SET NAMES utf8'
character-set-server = utf8
```

After a restart, check these with `SHOW variables LIKE 'char%'` and `SHOW variables LIKE 'collation%'`

## Users

Add any users we require for remote connections:

```
CREATE USER 'foo'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'foo'@'%' WITH GRANT OPTION;
```

Verify users priviledges with `SHOW GRANTS FOR 'foo'@'%';` and use `FLUSH PRIVILEGES;` if nothing appears / update changes.

The `%` allows from <strong>any</strong> host, although we have a firewall it's safer to set this to a specific host/ip

## Basic tuning

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
