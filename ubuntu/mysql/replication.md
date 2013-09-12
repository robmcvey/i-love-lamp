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

Taking a dump of the current master is done with `mysqldump` with a few specific options.

`mysqldump -u user -pPassword databaseName \
-v \ 						# verbose
--skip-lock-tables \		# Dont lock all the tables
--single-transaction \		# Esures data accross all tables are at the same point in time
--flush-logs \ 				# Flush logs file in server before starting dump
--hex-blob \				# Dump binary strings (BINARY, VARBINARY, BLOB) in hexadecimal format
--master-data=2 \			# This causes the binary log position and filename to be appended to the output
> /path/to/backup.sql`