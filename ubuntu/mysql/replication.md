# Replication

These guide is my own reference for configuring, managing and rescuing from a failover type scenario.

## Master

Setting up replication requires one instance of MySQL to be a "master". If already in production, there will be a small amount of disruption while it is configured and restarted.

In `/etc/mysql/my.cnf` you'll need to add or uncomment the following:

```
[mysqld]

server-id=1

binlog-format   = mixed

log-bin=mysql-bin

datadir=/var/lib/mysql

innodb_flush_log_at_trx_commit=1

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