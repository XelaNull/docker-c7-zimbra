# Start from Official CentOS Docker image
FROM centos:7
# This Docker image installs Zimbra 8.8.11, along with syslog-ng & Cron.
# Zimbra has its own Cron requirements. Custom daily Zimbra backup scripts also utilize Cron.

# CONFIGURE THESE ENVIRONMENTAL VARIABLES BELOW WITH THE DETAILS OF YOUR ENVIRONMENT
# Your local timezone
ENV TIMEZONEID=America/New_York
# The primary password to use for initial "admin" account
ENV PASSWORD=Sup3rS3cr3tM41lP4ssw0rd!
# This variable should contain all network ranges that this server and your servers reside on
# For most, the defaults set here probably would suffice.
ENV MTANETWORKS="127.0.0.0/8 172.17.0.0/16 10.0.0.0/16 192.168.0.0/8"
# Amount of system memory(in GB) to expect to be able to provide to Zimbra. 3.8 = 4GB
ENV SYSTEMMEMORY=3.8

# These first three variables you shouldn't really need to modify unless updating the version on the ZIMBRAURL
ENV ZIMBRAURL=https://files.zimbra.com/downloads/8.8.11_GA/zcs-8.8.11_GA_3737.RHEL7_64.20181207111719.tgz
ENV PREINSTALL_DIR=/opt/zimbra-install
ENV DOCKER_SYSTEMLOGS=/proc/1/fd/1

# Update YUM, then Install Pre-requisites
RUN yum -y --setopt=tsflags=nodocs update && yum -y --setopt=tsflags=nodocs install epel-release wget perl openssh-server telnet net-tools which && \
    yum -y --setopt=tsflags=nodocs install supervisor cronie openssh sudo perl-Sys-Syslog perl-Digest-MD5 syslog-ng sysstat unzip libaio nmap-ncat
# Disable Syslog-NG attempting to log kernel messages which arent available to a Docker container
RUN sed -i 's/system()/# system()/g' /etc/syslog-ng/syslog-ng.conf

# This scripts either performs full automated install(if uninstalled) or starts Zimbra. 
# Failed services are automatically restarted.
COPY zimbra-run.sh /zimbra-run.sh
# Copy in the Zimbra Cold Backup script
COPY zimbra-backup.sh /zimbra-backup.sh
RUN ln -s /zimbra-backup.sh /etc/cron.daily/zimbra-backup.sh

# If you plan to examine or manipulate the Zimbra files outside the running Docker image, you may want to consider creating
# the zimbra user with same UID as below on your Docker host to ensure directory listings properly map to the zimbra user.
RUN if [[ -z `getent passwd zimbra` ]]; then adduser -u 1000 -d /opt/zimbra zimbra; fi && \
    echo "zimbra ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
RUN mkdir $PREINSTALL_DIR && chown zimbra $PREINSTALL_DIR

# IMAPCopy - http://www.ardiehl.de/imapcopy/
# Used to copy all mail between two IMAP accounts & IMAP servers. Useful for migrating mail per account.
RUN cd $PREINSTALL_DIR && wget http://www.ardiehl.de/imapcopy/imapcopy.tar.gz || true
#zExtras Suite - TCP 8735 & 8736 - https://wiki.zextras.com/wiki/ZeXtras_Suite_Installation_Guide
# Paid software (with free trial) that has server-to-server migration utility
RUN cd $PREINSTALL_DIR && wget http://download.zextras.com/zextras_suite-latest.tgz || true

# Generate Supervisor configuration
RUN printf '[supervisord]\nnodaemon=true\nuser=root\nlogfile=/var/log/supervisord\n' > /etc/supervisord.conf && \
    echo $'#!/bin/bash \necho "[program:$1]";\necho "process_name  = $1";\n\
    echo "autostart     = true";\necho "autorestart   = false";\necho "directory     = /";\n\
    echo "command       = $2";\necho "startsecs     = 3";\necho "priority      = 1";\n\n' > /gen_sup.sh && \
    chmod a+x /*.sh
RUN /gen_sup.sh crond "/usr/sbin/crond -n" >> /etc/supervisord.conf && \
    /gen_sup.sh syslog-ng "/usr/sbin/syslog-ng --no-caps -F" >> /etc/supervisord.conf && \
    /gen_sup.sh zimbra "/zimbra-run.sh -d" >> /etc/supervisord.conf
RUN yum -y update && yum clean all && rm -rf /tmp/* && rm -rf /var/tmp/* && rm -rf /var/cache/* && rm -rf /var/log/* 

EXPOSE 25 80 443 465 587 110 143 993 995 7071 8080 8443 8735 8736
VOLUME ["/opt/zimbra"]
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
