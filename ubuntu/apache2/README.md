# Apache 2

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

95.123.456.789  apache-01.domain.com apache-01
10.123.456.7    apache-01.domain.com apache-01
```

## Check hostname

`hostname` should give short name, apache-01. `hostname -f` should give FQDN `apache-01.domain.com`.

## Firewall

`ufw status` will show firewall is <strong>not</strong> enabled.

Set the default rule as deny with `ufw default deny` then add our rules:

```
ufw allow ssh
ufw allow www
ufw allow https
```

To allow ssh from only a specific IP (recommended) use `ufw allow from 85.123.432.22 to any port 22` instead.

Turn on the firewall: `ufw disable && ufw enable` and confirm with `ufw status`.

## Package

```
apt-get install apache2
```

You will also need to install the packages to support whatever you are hosting, PHP, Python etc.

## Extras

#### SSL

Symlink the ssl mods

```
ln -s /etc/apaches2/mods-available/ssl.load /etc/apaches2/mods-enabled/ssl.load
ln -s /etc/apaches2/mods-available/ssl.conf /etc/apaches2/mods-enabled/ssl.conf
```

Need to listen on port 443, so edit `/etc/apache2/ports.conf` and add `NameVirtualHost *:443`

Configure virtual host (see `/etc/apache/sites-available` for defaults)

```
<VirtualHost *:443>
        SSLEngine on
        SSLCertificateFile    /etc/ssl/certs/ssl-cert-snakeoil.pem
        SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
        SSLCertificateChainFile /etc/ssl/certs/authority.crt
        DocumentRoot /var/www
</VirtualHost>
```

Once you've installed your own signed SSL cert, remove password from server key (unless you enjoy entering the cert password everytime you restart apache!)

```
cd /etc/apache2/ssl/certs
cp server.key server.key.backup
openssl rsa -in server.key.backup -out server.key
```

#### SSL config

Ensure we have SSL disabled and we're only using TLS. Update config in `/etc/apache2/mods-enabled/ssl.conf` as follows;

```
SSLProtocol All -SSLv2 -SSLv3
SSLHonorCipherOrder on
SSLCipherSuite ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA
```
