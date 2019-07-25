#!/bin/bash
# The HOSTNAME & DOMAIN are extracted from the system hostname, which is set via:
#  --hostname CLI argument from the 'docker run' command
HOSTNAME=$(hostname -f | cut -d. -f1)
DOMAIN=$(hostname -f | cut -d. -f2-)

# Declare Start/Stop Function
function stop_start() {
  echo "zimbra-run: Stopping Zimbra.." >> $DOCKER_SYSTEMLOGS
  /opt/zimbra/libexec/zmfixperms; su - zimbra -c "zmcontrol stop && sleep 5"  >> $DOCKER_SYSTEMLOGS
  # Make *SURE* all Zimbra processes are killed. A hung process would mean on restart it would not start cleanly.
  if [[ `ps awwux | grep zimbra | grep -v grep` ]]; then pkill -u zimbra; fi
  echo "zimbra-run: Re-Starting Zimbra.." >> $DOCKER_SYSTEMLOGS
  su - zimbra -c "zmcontrol start" >> $DOCKER_SYSTEMLOGS
}

# MAIN LOOP:
# Install Zimbra if it isn't already installed
if [[ -z $(ls -A /opt/zimbra) ]]; then sleep 3
  for i in {1..3}; do echo "******************************************" >> $DOCKER_SYSTEMLOGS; done
  echo "INSTALLING ZIMBRA COLLABORATION SOFTWARE.." >> $DOCKER_SYSTEMLOGS;
  # Disable IPv6 Entries in /etc/hosts
  cp /etc/hosts /etc/hosts2 && sed -i '2,6d' /etc/hosts2 && yes | cp /etc/hosts2 /etc/hosts
  
  # Download Zimbra to our pre-installation staging directory
  wget -O $PREINSTALL_DIR/zimbra-zcs.tar.gz $ZIMBRAURL
  tar xzvf $PREINSTALL_DIR/zimbra-zcs.tar.gz -C $PREINSTALL_DIR/

  echo "zimbra-run: Creating Zimbra keystrokes (Auto-response) file" >> $DOCKER_SYSTEMLOGS && \
      printf "y\ny\ny\ny\ny\nn\ny\ny\ny\ny\ny\ny\ny\ny\nn\ny" > $PREINSTALL_DIR/installZimbra-keystrokes
  # Create random strings for various email addresses    
  RANDOMHAM=$(date +%s|sha256sum|base64|head -c 10); sleep 1
  RANDOMSPAM=$(date +%s|sha256sum|base64|head -c 10); sleep 1
  RANDOMQUARANTINE=$(date +%s|sha256sum|base64|head -c 10); sleep 1
  RANDOMGALSYNC=$(date +%s|sha256sum|base64|head -c 10)
  # Create primary configuration file
cat <<EOF >$PREINSTALL_DIR/installZimbraScript
AVDOMAIN="$DOMAIN"
AVUSER="admin@$DOMAIN"
CREATEADMIN="admin@$DOMAIN"
CREATEADMINPASS="$PASSWORD"
CREATEDOMAIN="$DOMAIN"
DOCREATEADMIN="yes"
DOCREATEDOMAIN="yes"
DOTRAINSA="yes"
EXPANDMENU="no"
GALSYNC="galsync.$RANDOMGALSYNC@$DOMAIN"
HOSTNAME="$HOSTNAME.$DOMAIN"
HTTPPORT="8080"
HTTPPROXY="TRUE"
HTTPPROXYPORT="80"
HTTPSPORT="8443"
HTTPSPROXYPORT="443"
IMAPPORT="7143"
IMAPPROXYPORT="143"
IMAPSSLPORT="7993"
IMAPSSLPROXYPORT="993"
INSTALL_WEBAPPS="service zimlet zimbra zimbraAdmin"
JAVAHOME="/opt/zimbra/common/lib/jvm/java"
LDAPAMAVISPASS="$PASSWORD"
LDAPPOSTPASS="$PASSWORD"
LDAPROOTPASS="$PASSWORD"
LDAPADMINPASS="$PASSWORD"
LDAPREPPASS="$PASSWORD"
LDAPBESSEARCHSET="set"
LDAPDEFAULTSLOADED="1"
LDAPHOST="$HOSTNAME.$DOMAIN"
LDAPPORT="389"
LDAPREPLICATIONTYPE="master"
LDAPSERVERID="2"
MAILBOXDMEMORY="512"
MAILPROXY="TRUE"
MODE="https"
MYSQLMEMORYPERCENT="30"
POPPORT="7110"
POPPROXYPORT="110"
POPSSLPORT="7995"
POPSSLPROXYPORT="995"
PROXYMODE="https"
REMOVE="no"
RUNARCHIVING="no"
RUNAV="yes"
RUNCBPOLICYD="no"
RUNDKIM="yes"
RUNSA="yes"
RUNVMHA="no"
SERVICEWEBAPP="yes"
SMTPDEST="admin@$DOMAIN"
SMTPHOST="$HOSTNAME.$DOMAIN"
SMTPNOTIFY="yes"
SMTPSOURCE="admin@$DOMAIN"
SNMPNOTIFY="yes"
SNMPTRAPHOST="$HOSTNAME.$DOMAIN"
SPELLURL="http://$HOSTNAME.$DOMAIN:7780/aspell.php"
STARTSERVERS="yes"
SYSTEMMEMORY="$SYSTEMMEMORY"
TRAINSAHAM="ham.$RANDOMHAM@$DOMAIN"
TRAINSASPAM="spam.$RANDOMSPAM@$DOMAIN"
UIWEBAPPS="yes"
UPGRADE="yes"
USEKBSHORTCUTS="TRUE"
USESPELL="yes"
VERSIONUPDATECHECKS="TRUE"
VIRUSQUARANTINE="virus-quarantine.$RANDOMQUARANTINE@$DOMAIN"
ZIMBRA_REQ_SECURITY="yes"
ldap_bes_searcher_password="$PASSWORD"
ldap_dit_base_dn_config="cn=zimbra"
ldap_nginx_password="$PASSWORD"
ldap_url="ldap://$HOSTNAME.$DOMAIN:389"
mailboxd_directory="/opt/zimbra/mailboxd"
mailboxd_keystore="/opt/zimbra/mailboxd/etc/keystore"
mailboxd_keystore_password="$PASSWORD"
mailboxd_server="jetty"
mailboxd_truststore="/opt/zimbra/common/lib/jvm/java/jre/lib/security/cacerts"
mailboxd_truststore_password="changeit"
postfix_mail_owner="postfix"
postfix_setgid_group="postdrop"
ssl_default_digest="sha256"
zimbraDNSMasterIP=""
zimbraDNSTCPUpstream="no"
zimbraDNSUseTCP="yes"
zimbraDNSUseUDP="yes"
zimbraDefaultDomainName="$DOMAIN"
zimbraFeatureBriefcasesEnabled="Enabled"
zimbraFeatureTasksEnabled="Enabled"
zimbraIPMode="ipv4"
zimbraMailProxy="FALSE"
zimbraMtaMyNetworks="$MTANETWORKS"
zimbraPrefTimeZoneId="$TIMEZONEID"
zimbraReverseProxyLookupTarget="TRUE"
zimbraVersionCheckInterval="1d"
zimbraVersionCheckNotificationEmail="admin@$DOMAIN"
zimbraVersionCheckNotificationEmailFrom="admin@$DOMAIN"
zimbraVersionCheckSendNotifications="TRUE"
zimbraWebProxy="FALSE"
zimbra_ldap_userdn="uid=zimbra,cn=admins,cn=zimbra"
zimbra_require_interprocess_security="1"
zimbra_server_hostname="$HOSTNAME.$DOMAIN"
INSTALL_PACKAGES="zimbra-core zimbra-ldap zimbra-logger zimbra-mta zimbra-snmp zimbra-store zimbra-apache zimbra-spell zimbra-memcached zimbra-proxy"
EOF

  echo "zimbra-run: Running install.sh Zimbra Installer.." >> $DOCKER_SYSTEMLOGS
  cd $PREINSTALL_DIR/zcs-* && ./install.sh -s < $PREINSTALL_DIR/installZimbra-keystrokes >> $DOCKER_SYSTEMLOGS

  # BUGFIX: Docker-based Zimbra has bug with zmcontrol not properly starting LDAP service first.
  # This bugfix injects a manual ldap start right before the 'zmcontrol start' command is issued.
  # This ensures LDAP is started first and all services starting after it have this dependency met.
  # Without this fix, Zimbra Installation fails steps of "Installing common zimlets" and "Creating galsync account for default domain"
  linenum=`grep -rne 'zmcontrol stop' /opt/zimbra/libexec/zmsetup.pl | cut -d: -f1`; LINE_TO_INSERT_AT=`expr $linenum + 1`
  sed -i "${LINE_TO_INSERT_AT}i runAsZimbra (\"~/bin/ldap start\");" /opt/zimbra/libexec/zmsetup.pl
  
  echo "zimbra-run: Running zmsetup.pl.." >> $DOCKER_SYSTEMLOGS
  /opt/zimbra/libexec/zmsetup.pl -c $PREINSTALL_DIR/installZimbraScript >> $DOCKER_SYSTEMLOGS
  # Force Cron to reload configuration
  kill --signal HUP `ps awwx | grep cron | grep -v grep | awk '{print $1}'`;
  echo "zimbra-run: Taking first initial backup" >> $DOCKER_SYSTEMLOGS
  /zimbra-backup.sh
  for i in {1..2}; do echo "--------------------------------------------------" >> $DOCKER_SYSTEMLOGS; done
  echo "COMPLETED INSTALLATION ZIMBRA COLLABORATION SERVER" >> $DOCKER_SYSTEMLOGS
  echo "Zimbra Webmail URL: https://$HOSTNAME.$DOMAIN" >> $DOCKER_SYSTEMLOGS
  echo "Zimbra Admin URL: https://$HOSTNAME.$DOMAIN:7071" >> $DOCKER_SYSTEMLOGS
  echo "Zimbra Password: $PASSWORD" >> $DOCKER_SYSTEMLOGS
  echo "---"  >> $DOCKER_SYSTEMLOGS; echo "zimbra-run: You may now hit CTRL-C to stop this running Docker image. Then issue your 'docker start' command to restart it in the background." >> $DOCKER_SYSTEMLOGS
fi

if [[ $1 == "-d" ]]; then
while :; do
  # Determine if one or many serveices are stopped
  STOPPED_COUNT=`su - zimbra -c "zmcontrol status | grep Stopped | wc -l"`

  BACKUP_CHECK=`ps awwux | grep zimbra-backup | grep -v grep`
  if [[ $BACKUP_CHECK != "" ]]; then
    echo "zimbra-run: Detected backup running. Skipping loop."
    STOPPED_COUNT=0
  fi
  
  ZMCONTROL_CHECK=`ps awwux | grep zmcontrol | grep -v grep`
  if [[ $ZMCONTROL_CHECK != "" ]]; then
    echo "zimbra-run: Detected zmcontrol is currently being run. Skipping loop."
    STOPPED_COUNT=0
  fi

  # If one service is stopped, examine if we recently have tried to restart it.
  if [[ $STOPPED_COUNT == "1" ]]; then
    # Obtain the name of the one service that is stopped
    export STOPPED_SERVICE=`sudo -u zimbra /opt/zimbra/bin/zmcontrol status | grep Stopped | awk '{print $1}'`
    echo "zimbra-run: Service Found Stopped: $STOPPED_SERVICE" >> $DOCKER_SYSTEMLOGS;

    # Determine the number of times we have recently restarted this
    LAST_SERVICE_RESTART=`grep $STOPPED_SERVICE /var/log/zmmonitor.log | tail -1 | awk '{print $1}'`
    if [[ $LAST_SERVICE_RESTART < `date -d '- 10 minutes' +%s` ]]; then
      # Flag this service in a log file with a UNIX timestamp
      echo "$(date +%s) $STOPPED_SERVICE" >> /var/log/zmmonitor.log
      echo "zimbra-run: Restarting Stopped Service: $STOPPED_SERVICE" >> $DOCKER_SYSTEMLOGS;

      # If we have not, go ahead and restart it
      CONTROL_EXEC=`grep $STOPPED_SERVICE /opt/zimbra/bin/zmcontrol | grep bin | cut -d'"' -f4`
      echo "zimbra-run: Utilizing $CONTROL_EXEC to restart $STOPPED_SERVICE" >> $DOCKER_SYSTEMLOGS;
      `sudo -u zimbra $CONTROL_EXEC restart`
    else  # If we have recently restarted this service, we should attempt a full application stack restart
      echo "zimbra-run: Detected multiple restarts of this service recently. Forcing full application restart." >> $DOCKER_SYSTEMLOGS;
      STOPPED_COUNT=2
    fi
  fi
  # If more than one service is stopped, attempt an application stack restart
  if [[ $STOPPED_COUNT > 1 ]]; then
    STOPPED_SERVICES=`su - zimbra -c "zmcontrol status | grep Stopped"`
    echo "zimbra-run: Automatically Restarting Zimbra due to service failure: $STOPPED_SERVICES" >> $DOCKER_SYSTEMLOGS;
    stop_start "Auto-Restart due to service failure: $RESULT";
  fi

  sleep 300
  echo "zimbra-run: Looping & Checking All Services Started Status"
done
fi
