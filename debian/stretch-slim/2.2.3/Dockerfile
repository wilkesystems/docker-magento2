FROM debian:stretch-slim

MAINTAINER wilkesystems <maintainer@wilke.systems>

ADD magento2.tar.xz /

ENV MAGE_ROOT="/var/www"

RUN apt-get update; \
apt-get install -y bzip2 ca-certificates cron composer curl exim4-daemon-light git \
graphicsmagick imagemagick locales locales-all mysql-client nginx-extras openssl p7zip \
php-apcu php-bcmath php-bz2 php-cgi php-cli php-curl php-dba php-enchant php-fpm \
php-gd php-gmp php-imagick php-imap php-interbase php-intl php-json php-ldap \
php-mbstring php-mcrypt php-mysql php-opcache php-pear php-pgsql php-pspell \
php-readline php-recode php-snmp php-soap php-sqlite3 php-sybase php-tidy \
php-xml php-xmlrpc php-xsl php-zip redis-server redis-tools rrdtool rsyslog snmp \
ssl-cert supervisor unzip varnish wget xz-utils; \
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 80/tcp 443/tcp 9001/tcp

COPY ["docker-entrypoint.sh", "/usr/bin/docker-entrypoint.sh"]

WORKDIR $MAGE_ROOT

CMD ["supervisord"]

ENTRYPOINT ["docker-entrypoint.sh"]