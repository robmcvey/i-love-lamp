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

# Enable binary logging. The server logs all statements that change data
log-bin=mysql-bin
log_bin = /var/log/mysql/mysql-bin.log

# Only keep logs for 1 week, max 100mb per file as not to fill disk!
expire_logs_days = 7
max_binlog_size = 100M

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

### Create replication user

We also need to add a slave user on our master. This allows our slave(s) to connect from, and only from, the IPs defined in the `GRANT` statement used to create said user.

```
CREATE USER 'replicant'@'<<slave-server-ip>>';
GRANT REPLICATION SLAVE ON *.* TO 'replicant'@'<<slave-server-ip>>' IDENTIFIED BY '<<choose-a-long-password>>';
FLUSH PRIVILEGES;
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
mysqldump -u user -pPassword \
-v \
--skip-lock-tables \
--single-transaction \
--flush-logs \
--hex-blob \
--master-data=2 \
--databases {my-database} \
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

```

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
```

We can now start up our slave. It will automatically check the bin log position of master and get any updates since we took our original dump.

```
START SLAVE;
```

This can be verified by viewing slave status:

```
SHOW SLAVE STATUS \G
```

If all is well, Last_Error will be blank, and Slave_IO_State will report "Waiting for master to send event". You'll also notice if you compare the `Exec_Master_Log_Pos` it will match the current posision of our master.

```
mysql> show slave status\G
*************************** 1. row ***************************
Slave_IO_State: Waiting for master to send event
Master_Host: <<master-server-ip>>
Master_User: replicant
Master_Port: 3306
Connect_Retry: 60
Master_Log_File: mysql-bin.000002
Read_Master_Log_Pos: 1044
Relay_Log_File: mysql-relay-bin.000002
Relay_Log_Pos: 1190
Exec_Master_Log_Pos: 1510
Relay_Master_Log_File: mysql-bin.000002
Last_Error:

...

```

## Failover scenario

For this section we'll assume there is only one master, with a single slave. 

Replication was running fine then BOOM. The master is dead.

### Promoting the slave

If you view the status of the slave it will be trying to connect to the failed master:

```
mysql> show slave status\G
*************************** 1. row ***************************
Slave_IO_State: Reconnecting after a failed master event read
Slave_IO_Running: Connecting
Slave_SQL_Running: Yes
Last_IO_Errno: 2003
Last_IO_Error: error reconnecting to master 'replicant@<<master-server-ip>>' - retry-time: 60  retries: 86400
```

We need to stop replication, promote the slave to become our new master then configure our application to begin writing to it.

So, on the slave being promoted to master, issue `STOP SLAVE` and `RESET MASTER`.

`STOP SLAVE` kills the slave process, and `RESET MASTER` resets the binlog position and clears any binlog files on the slave (we do this just in case the slave was at one point itself a master).

Our application can now continue operating (i.e. edit your app's database configuration). From here you can then begin the replication configuration as described above, editing the new master's my.cnf file to begin all over again by taking a SQL dump with log file/position information and building a new slave machine.

### Multiple slaves

This section assumes you have relay-logging enabled, and up-to-date bin-logs are present on all slaves.

If there were multiple slaves running when the old master failed, they too would be in a `error reconnecting` state. Shut down your web application while a new master is configured and replication resumed. 

<b>You don't want any database writes occuring ANYWHERE during this scenario!</b>

First, make sure that all slaves have processed any statements in their relay log. On each slave, issue `STOP SLAVE IO_THREAD` and check the output of `SHOW PROCESSLIST` until you see `Has read all relay log`.

If not all updates have been processed, you'd choose the most up to date slave to promote. On the machine you choose to become the new master, issue `RESET MASTER` and get the current log file and position info:

```
mysql> SHOW MASTER STATUS;
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000003 |     4324 |              |                  |
+------------------+----------+--------------+------------------+
1 row in set (0.00 sec)
```

Ensure the new master has a replication user and password setup to allow connections from the other slaves (see "Create replication user" above).

Then, on the remaining slaves, issue the `CHANGE MASTER TO` command with the new log file and position info of the new master:

```
CHANGE MASTER TO \
MASTER_HOST='<<new-master-server-ip>>', \
MASTER_USER='replicant', \
MASTER_PASSWORD='<<slave-server-password>>', \
MASTER_LOG_FILE='mysql-bin.000003', \
MASTER_LOG_POS=4324;
```

After checking `show slave status` you're ready to go. Start your application with writes configured to go to the new master.

## References

http://dev.mysql.com/doc/refman/5.5/en/replication-solutions-switch.html

http://plusbryan.com/mysql-replication-without-downtime
