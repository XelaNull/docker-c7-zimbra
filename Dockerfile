# Start from Official CentOS Docker image
FROM centos:7

# This Docker image installs Zimbra 8.8.11, along with syslog-ng & cron.
# Cron is necessary to facilitate built-in backup scripts
# You should be able to just modify the variables above and then build the image
# using the instructions from the README.md file.

# CONFIGURE THESE ENVIRONMENTAL VARIABLES BELOW WITH THE DETAILS OF YOUR ENVIRONMENT
# Your local timezone
ENV TIMEZONEID=America/New_York
# Simple/Short Hostname (no domain)
ENV HOSTNAME=LEATHERBACK
# Your primary domain
ENV DOMAIN=shouden.us
# Your server's external IP address. This should be the IP that DNS resolves your FQDN as.
###ENV EXTERNALIP=199.59.82.222
# The primary password to use for initial "admin" account
ENV PASSWORD=Sup3rS3cr3tM41lP4ssw0rd!
# List of IP ranges that cover Docker containers, as well as any IP ranges your server may sit on
ENV MTANETWORKS="127.0.0.0/8 172.17.0.0/16 10.0.0.0/16 [::1]/128 [fe80::]/64"
# Amount of system memory to expect to be able to provide to Zimbra. 3.8 = 4GB
ENV SYSTEMMEMORY=3.8

# These first three variables you shouldn't really need to modify unless updating the version on the ZIMBRAURL
ENV ZIMBRAURL=https://files.zimbra.com/downloads/8.8.11_GA/zcs-8.8.11_GA_3737.RHEL7_64.20181207111719.tgz
ENV PREINSTALL_DIR=/opt/zimbra-install
ENV DOCKER_SYSTEMLOGS=/proc/1/fd/1

# Update YUM, then Install Pre-requisites
RUN yum -y --setopt=tsflags=nodocs update && yum -y --setopt=tsflags=nodocs install epel-release wget perl openssh-server telnet net-tools which && \
    yum -y --setopt=tsflags=nodocs install supervisor cronie openssh sudo perl-Sys-Syslog perl-Digest-MD5 syslog-ng sysstat unzip libaio nmap-ncat
RUN echo "zimbra ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
# Disable Syslog attempting to log kernel messages which arent available to a Docker container
RUN sed -i 's/system()/# system()/g' /etc/syslog-ng/syslog-ng.conf
# Remove IPv6 entries from /etc/hosts file
# RUN cp /etc/hosts /etc/hosts2 && sed -i '2,6d' /etc/hosts2 && yes | cp /etc/hosts2 /etc/hosts

# This script examines the Zimbra installation directory figure out if it is installed
# If Zimbra isn't installed, it kicks off the full automated installation
# If Zimra is already installed, it simply starts Zimbra
# This script also serves the purpose to restart the application stack if an individual service is found failed.
COPY zimbra-run.sh /zimbra-run.sh

# Ideally you want the zimbra user to exist on the host Docker system too so that when you examine the files in the 
# persistent volume outside the container, you will see the appropriate user ownership. This step will create the 
# zimbra user with a consistent UID=1000 & Postfix with consistent UID=1001
# Create the same usernames with the same UIDs on your host system, if you care about this ownership showing properly.
RUN if [[ -z `getent passwd zimbra` ]]; then adduser -u 1000 -d /opt/zimbra zimbra; fi
RUN if [[ -z `getent passwd postfix` ]]; then adduser -u 1001 -d /opt/zimbra/postfix postfix; fi
RUN mkdir /opt/zimbra-install && chown zimbra /opt/zimbra-install

# These next two are not mandatory, but I've chosen to at least include them
# these are to help facilitate migration between Zimbra servers with community edition
# IMAPCopy - http://www.ardiehl.de/imapcopy/
RUN cd /opt/zimbra-install && wget http://www.ardiehl.de/imapcopy/imapcopy.tar.gz
# tar zxvf imapcopy.tar.gz
#zExtras Suite - TCP 8735 & 8736 - https://wiki.zextras.com/wiki/ZeXtras_Suite_Installation_Guide
RUN cd /opt/zimbra-install && wget http://download.zextras.com/zextras_suite-latest.tgz
# tar zxvf zextras_suite-latest.tgz && cd zextras-suite*; ./install.sh all

# Configure supervisord
RUN { \
    echo '[supervisord]'; \
    echo 'nodaemon        = true'; \
    echo 'user            = root'; \
    echo 'logfile         = /var/log/supervisord'; echo; \
    echo '[program:crond]'; \
    echo 'process_name    = crond'; \
    echo 'autostart       = true'; \
    echo 'autorestart     = unexpected'; \
    echo 'directory       = /'; \
    echo 'command         = /usr/sbin/crond -n'; \
    echo 'startsecs       = 3'; \
    echo 'priority        = 1'; echo; \
    echo '[program:syslog-ng]'; \
    echo 'process_name    = syslog-ng'; \
    echo 'autostart       = true'; \
    echo 'autorestart     = unexpected'; \
    echo 'directory       = /'; \
    echo 'command         = /usr/sbin/syslog-ng --no-caps -F'; \
    echo 'startsecs       = 3'; \
    echo 'priority        = 1'; \
    echo '[program:zimbra]'; \
    echo 'process_name    = zimbra'; \
    echo 'autostart       = true'; \
    echo 'autorestart     = unexpected'; \
    echo 'directory       = /'; \
    echo 'command         = /zimbra-run.sh -d'; \
    echo 'startsecs       = 3'; \
    echo 'priority        = 1'; echo; \
    } | tee /etc/supervisord.conf

RUN yum -y update && yum clean all && rm -rf /tmp/* && rm -rf /var/tmp/* && rm -rf /var/cache/* && rm -rf /var/log/* && chmod a+x /*.sh
EXPOSE 25 80 443 465 587 110 143 993 995 7071 8080 8443 8735 8736
VOLUME ["/opt/zimbra"]
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
