## A basic backup routine using s3cmd and mysqldump

These two commands can be run as cron jobs.

Mysqldump will prepend the SQL file names with the day.

```bash
mysqldump -u root -p -v --skip-lock-tables --single-transaction --flush-logs --hex-blob --ignore-table=db.sometable_i_want_to_skip --master-data=2 copify > /var/backups/mysql/`date +%a`_dump.sql
```

Store on Amazon S3.

```bash
s3cmd put --verbose --recursive --no-encrypt --no-check-md5 /var/backups/mysql/ s3://bucket/backups/mysql/
```
