## Fail2Ban

### Configure

```
# Copify custom rules /etc/fail2ban/filter.d/copify.conf
#
# Matches e.g.
# 12.34.33.22 - [07/Jun/2014:11:15:29] "POST /wp/wp-login.php HTTP/1.0" 200 4523
#
[Definition]

failregex = ^<HOST> .* "GET /wp-.+" 404
			^<HOST> .* "GET /.+\.php\s.+" 404
			^<HOST> .* "GET /.+\.asp\s.+" 404
			^<HOST> .* "GET /.+\.aspx\s.+" 404
			^<HOST> .* "GET /admin.+" 404
			^<HOST> .* "GET /\+\+.+" 404
	
ignoreregex =
```

Enable jail in /etc/fail2ban/jail.conf

```bash
[copify]

enabled  = true
port     = http,https
filter   = copify
logpath  = /var/log/apache*/*access.log
maxretry = 6

[ssh]

enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 6
```

### Testing 

```
fail2ban-regex '37.57.231.239 - - [22/Apr/2015:16:42:12 +0100] "GET /ddos.phpindex.php HTTP/1.0" 404' /etc/fail2ban/filter.d/copify.conf
```

### Unblock

Manually Unban <IP> in <JAIL>

`set <JAIL> unbanip <IP>` 

e.g.

```
$ sudo fail2ban-client set copify unbanip 217.144.52.94
```

## Fail2Ban handy rules

```bash
# wordpress pests
^<HOST> .* "POST /wp-comments-post.+"
^<HOST> .* "POST /wp-login.+"
^<HOST> .* "POST /.+\.php\s.+" 404
```
