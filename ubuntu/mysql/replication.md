# Replication

These guide is my own reference for configuring, managing and rescuing from a failover type scenario with MySQL replication.

Note: It assumes InnoDB engine is used!

## Master

Setting up replication requires one instance of MySQL to be a "master". If already in production, there will be a small amount of disruption while it is configured and restarted.

In `/etc/mysql/my.cnf` you'll need to add or uncomment the following:

```bash
[mysqld]

# This option is common to both master and slave replication servers, to identify themselves uniquely.
server-id=1

# Causes logging to use mixed format. 
binlog-format=mixed

# Enable binary logging. The server logs all statements that change data
log-bin=mysql-bin

# Specifiy our data directory
datadir=/var/lib/mysql

# When the value is 1, the log buffer is written out to the log file at each transaction commit
innodb_flush_log_at_trx_commit=1

# MySQL server synchronizes its binary log to disk after writing to the binary log
sync_binlog=1
```

MySQL can then be restarted, and you now have a master database server.

```
mysql> show master status;
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000001 |      107 |              |                  |
+------------------+----------+--------------+------------------+
1 row in set (0.00 sec)
```

We also need to add a slave user on our master. This allows our slave(s) to connect from, and only from, the IPs defined in the `GRANT` statement used to create said user.

```
CREATE USER replicant@<<slave-server-ip>>;
GRANT REPLICATION SLAVE ON *.* TO replicant@<<slave-server-ip>> IDENTIFIED BY '<<choose-a-long-password>>';
```

Taking a dump of the current master is done with `mysqldump` with a few specific options. Typically, a mysql dump would be used to prepare a slave in the <b>exact</b> state the master is in before commencing replication. However, this means no writes can take place on the master while the dump is transfered and restored on the slave. 

We don't want or can't afford this downtime (which may be significant if a large database) so we'll also dump the bin log positions, meaning our new slave will know exactly where it needs to catch up from. 

We'll then start our slave and it will do the rest, getting all transactions since the initial dump was taken and eventually synchronizing itself. 

* `-v` Be verbose
* `--skip-lock-tables` Dont lock all the tables
* `--single-transaction` Ensures data accross all tables are at the same point in time
* `--flush-logs` Flush logs file in server before starting dump
* `--hex-blob` Dump binary strings (BINARY, VARBINARY, BLOB) in hexadecimal format
* `--master-data=2` This causes the binary log position and filename to be appended to the output
* `-A` Take all databases in the dump

```
mysqldump -u user -pPassword databaseName \
-v \
--skip-lock-tables \
--single-transaction \
--flush-logs \
--hex-blob \
--master-data=2 \
-A \
> /path/to/backup.sql
```

Once, complete you'll have the bin log file and bin log position included in the file. Take note of these, you'll need them when setting up the slave.

```bash
$ head -50 /path/to/backup.sql
-- MySQL dump 10.13
-- Server version	5.5.32-log

--
-- Position to start replication or point-in-time recovery from
--

-- CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.000002', MASTER_LOG_POS=107;

```

At this point, this guide assumes you have a second MySQL instance running which is to be used as a slave. 

First, lets send over our dump file:

```bash
$ scp /path/to/backup.sql user@<<slave ip>>:/tmp
```

While thaht's transfering, let's log in to the slave.

## Slave

We also need to edit our to to configure our slave to behave as such.

```bash
[mysqld]

server-id=101 

binlog-format=mixed

log_bin=mysql-bin

relay-log=mysql-relay-bin

#log-slave-updates=0

#read-only=0

```

### Slave options explained

This guide assumes you want to be prepared for the scenario of having to promote your slave to become the new master. As such, there are two options that have been ommited which might otherwise be used for a typical "read only" slave;

`log-slave-updates`

<blockquote>
Because updates received by a slave from the master are not logged in the binary log unless --log-slave-updates is specified, the binary log on each slave is empty initially. If for some reason MySQL Master becomes unavailable, you can pick one of the slaves to become the new master.

The reason for running the slave without --log-slave-updates is to prevent slaves from receiving updates twice in case you cause one of the slaves to become the new master	
</blockquote>

`read-only`

Our setup also assumes no other database (or web client) is connected to our slaves, so we can ignore the read only option. This will also mean we can switch to writing to any of our slaves in the event of a failover as fast as possible (opinions on this welcome, this is currently my best guess!)

### Restore data to slave

By now, our dump fiole should have transfered accross and will be in `/tmp`. Let's restore this on the slave:

```
mysql -u root -p < /tmp/backup.sql
```

Our slave now contains all the databases and records from the point in time the dump was taken.

We can now instruct our slave to begin listening to our master server, using the bin log file and position we noted down earlier. This tells the slave where to continue replicating from.

```
CHANGE MASTER TO \
MASTER_HOST='<<master-server-ip>>', \
MASTER_USER='replicant', \
MASTER_PASSWORD='<<slave-server-password>>', \
MASTER_LOG_FILE='<<value from above>>', \
MASTER_LOG_POS=<<value from above>>;
START SLAVE;

SHOW SLAVE STATUS \G
```

If all is well, Last_Error will be blank, and Slave_IO_State will report “Waiting for master to send event”.

## Failover scenario

http://dev.mysql.com/doc/refman/5.5/en/replication-solutions-switch.html




