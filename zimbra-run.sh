#!/bin/bash
# Install Zimbra if it isn't already installed
if [[ -z $(ls -A /opt/zimbra) ]]; then sleep 3
    echo "******************************************" >> $DOCKER_SYSTEMLOGS
    echo "******************************************" >> $DOCKER_SYSTEMLOGS
    echo "******************************************" >> $DOCKER_SYSTEMLOGS
    echo "INSTALLING ZIMBRA COLLABORATION SOFTWARE..";
    # Download Zimbra to our pre-installation staging directory
    PREINSTALL_DIR=/opt/zimbra-install
    CONFIGSCRIPT=$PREINSTALL_DIR/installZimbraScript
    
    mkdir $PREINSTALL_DIR
    wget -O $PREINSTALL_DIR/zimbra-zcs.tar.gz $ZIMBRAURL
    tar xzvf $PREINSTALL_DIR/zimbra-zcs.tar.gz -C $PREINSTALL_DIR/
    
    # These next two are not mandatory, but I've chosen to at least include them
    # these are to help facilitate migration between Zimbra servers with community edition
    # IMAPCopy - http://www.ardiehl.de/imapcopy/
    #cd /root && wget http://www.ardiehl.de/imapcopy/imapcopy.tar.gz && tar zxvf imapcopy.tar.gz
    #zExtras Suite - TCP 8735 & 8736 - https://wiki.zextras.com/wiki/ZeXtras_Suite_Installation_Guide
    #cd /root && wget http://download.zextras.com/zextras_suite-latest.tgz && tar zxvf zextras_suite-latest.tgz
    # cd zextras-suite*; ./install.sh all

    echo "Creating Zimbra keystrokes (Auto-response) file" && \
        printf "y\ny\ny\ny\ny\nn\ny\ny\ny\ny\ny\ny\ny\ny\nn\ny" > $PREINSTALL_DIR/installZimbra-keystrokes
        
    RANDOMHAM=$(date +%s|sha256sum|base64|head -c 10); sleep 1
    RANDOMSPAM=$(date +%s|sha256sum|base64|head -c 10); sleep 1
    RANDOMQUARANTINE=$(date +%s|sha256sum|base64|head -c 10); sleep 1
    RANDOMGALSYNC=$(date +%s|sha256sum|base64|head -c 10)

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

    echo "zimbra-run: Running zimbra-run.sh Installer.." >> $DOCKER_SYSTEMLOGS
    cd $PREINSTALL_DIR/zcs-* && ./install.sh -s < $PREINSTALL_DIR/installZimbra-keystrokes >> $DOCKER_SYSTEMLOGS

    echo "zimbra-run: Running zmsetup.pl.." >> $DOCKER_SYSTEMLOGS
    /opt/zimbra/libexec/zmsetup.pl -c $PREINSTALL_DIR/installZimbraScript >> $DOCKER_SYSTEMLOGS
    
    echo "zimbra-run: The above, may show failed zimlet installations. Not to worry, we're going to reinstall them in another minute!" >> $DOCKER_SYSTEMLOGS
    sleep 30
    start_zimbra "Starting Zimbra"
    
    echo "------------------------------------------" >> $DOCKER_SYSTEMLOGS
    echo "------------------------------------------" >> $DOCKER_SYSTEMLOGS    
    echo "zimbra-run: Setting Zimlets to Automatically Install in 60 seconds.." >> $DOCKER_SYSTEMLOGS
    echo "for A in /opt/zimbra/zimlets/*; do" > /install_zimlets.sh && \
    echo "  su - zimbra -c \"zmzimletctl deploy \$A\" >> $DOCKER_SYSTEMLOGS;" >> /install_zimlets.sh && \
    echo "done" >> /install_zimlets.sh && \
    echo 'echo "******************************************" >> $DOCKER_SYSTEMLOGS' >> /install_zimlets.sh && \
    echo 'echo "******************************************" >> $DOCKER_SYSTEMLOGS' >> /install_zimlets.sh && \ 
    echo 'echo "******************************************" >> $DOCKER_SYSTEMLOGS' >> /install_zimlets.sh && \
    echo 'echo "zimbra-run: Zimbra installed successfully." >> $DOCKER_SYSTEMLOGS' >> /install_zimlets.sh && \
    chmod a+x /install_zimlets.sh
    
    echo "zimbra-run: Now, we're going to reinstall the GAL sync account.." >> $DOCKER_SYSTEMLOGS
    su - zimbra -c "zmgsautil createAccount -a galsync.$RANDOMGALSYNC@$DOMAIN -n InternalGAL --domain $DOMAIN -s $HOSTNAME.$DOMAIN -t zimbra -f _InternalGAL"
    su - zimbra -c "zmgsautil forceSync -a galsync.$RANDOMGALSYNC@$DOMAIN -n InternalGAL"
    
    echo "------------------------------------------" >> $DOCKER_SYSTEMLOGS
    echo "------------------------------------------" >> $DOCKER_SYSTEMLOGS
    echo "zimbra-run: Completed Main Segment of Zimbra Install. Final Zimlet installation step will take up to 5 more minutes." >> $DOCKER_SYSTEMLOGS
    
    kill -9 `ps awwx | grep cron | grep -v grep | awk '{print $1}'`
    # Sleep for 5 minutes to ensure all processes start up properly, before loop condition starts
    sleep 300;
    echo "zimbra-run: Sleeping for 5 minutes before beginning loop." >> $DOCKER_SYSTEMLOGS
fi

function start_zimbra() {
# Fix any permissions issues that might exist
/opt/zimbra/libexec/zmfixperms;

# Start LDAP First
su - zimbra -c "ldap start && sleep 3 && zmcontrol start && echo \"zimbra-run: STARTED $1\" >> $DOCKER_SYSTEMLOGS"  
}

function stop_start() {
# Fix any permissions issues that might exist
/opt/zimbra/libexec/zmfixperms;
# Stop Zimbra
su - zimbra -c "zmcontrol stop && sleep 3 && echo \"$(date +%Y-%m-%d_%H:%i:%s) zimbra-run: STOPPED $1\" >> $DOCKER_SYSTEMLOGS";
# Start LDAP First
su - zimbra -c "ldap start && sleep 3 && zmcontrol start && echo \"zimbra-run: STARTED $1\" >> $DOCKER_SYSTEMLOGS";
}

if [[ $1 == "-d" ]]; then
while :; do
    RESULT=`su - zimbra -c "zmcontrol status | grep -v $(hostname | tr '[:upper:]' '[:lower:]') | grep -v Running"`;
    if [[ "$RESULT" != "" ]]; then
        echo "One or more Zimbra services detected as not running. Automatically restarting.";
        echo "zimbra-run: Automatically Restarting Zimbra due to service failure: $RESULT" >> $DOCKER_SYSTEMLOGS;
        stop_start "Auto-Restart due to service failure: $RESULT";
    else
      if [[ ! -f /INSTALLED_ZIMLETS ]]; then
        /install_zimlets.sh &
        touch /INSTALLED_ZIMLETS
      fi
    fi
    sleep 300
done
fi
