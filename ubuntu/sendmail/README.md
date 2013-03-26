# Sendmail

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

95.123.456.789  mail-01.domain.com mail-01
10.123.456.7    mail-01.domain.com mail-01
```

## Check hostname

`hostname` should give short name, mail-01. `hostname -f` should give FQDN `mail-01.domain.com`.

## Firewall

`ufw status` will show firewall is <strong>not</strong> enabled.

Set the default rule as deny with `ufw default deny` then add our rules:

```
ufw allow ssh
ufw allow smtp
```

To allow ssh from only a specific IP (recommended) use `ufw allow from 85.123.432.22 to any port 22` instead.

Also, this will be a dedicated mail server, so to prevent any possible issues with spammers, only open port 25 to your own devices.

Assuming `10.123.432.22` is our web server IP, only allow this:

`ufw allow from 10.123.432.22 to any port 25`.

Turn on the firewall: `ufw disable && ufw enable` and confirm with `ufw status`.

## Package

`apt-get install sendmail`

## Configure sendmail

Open `/etc/mail/sendmail.mc` and comment out the DAEMON_OPTIONS that restrict to localhost:

```
# DAEMON_OPTIONS(`Family=inet,  Name=MTA-v4, Port=smtp , Addr=127.0.0.1')dnl
# DAEMON_OPTIONS(`Family=inet,  Name=MSP-v4, Port=submission, M=Ea , Addr=127.0.0.1')dnl
```

Re-compile the config

`m4 sendmail.mc > sendmail.cf`

Once compiled, check the `Timeout.ident=1s` in sendmail.cf is only 1 second, seems to default to 5s which will mean the greeting banner is sloooow.

Now, allow relaying from only specified hosts, add domains/IPs one per line to `/etc/mail/relay-domains`

Allow local networked addresses to relay in `/etc/mail/access`

```
Connect:10                      RELAY
GreetPause:10                   0
ClientRate:10                   0
ClientConn:10                   0
```

Finally, rebuild `access` with:

`makemap hash access < access`

Restart the sendmail service and it should all be working.

`/etc/init.d/sendmail restart`

## Confirm with telnet

```
> telnet domain.com 25
> HELO mail-01.domain.com
> MAIL FROM:<system@somewhere.com>
> RCPT TO:<robmcvey@foobarfizzbang.com>
> DATA
> Subject: test message
> This is the body of the message!
> .

> QUIT
```
