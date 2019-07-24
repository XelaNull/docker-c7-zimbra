#!/bin/bash
export zimbra=/opt/zimbra

# Clone Zimbra directory to /backups folder. This is necessary in case /backups is stored on alternate storage. (safest approach)
echo "$(date +%Y%m%d_%H%M%s) Stopping Zimbra.."; su - zimbra -c '/opt/zimbra/bin/zmcontrol stop'
echo "Performing FULL rsync of /opt/zimbra to /backups/zimbra"
/usr/bin/rsync --delete --delete-excluded -a \
        --exclude data/amavisd/ \
        --exclude data/clamav/ \
        --exclude data/tmp \
        --exclude data/mailboxd/imap-inactive-session-cache.data \
        --exclude log \
        --exclude zmstat \
        --exclude data/ldap/mdb/db/data.mdb \
/opt/zimbra/* /backups/zimbra
echo "Performing sparse copy of data.mdb file from /opt/zimbra to /backups/zimbra"
yes | cp --sparse=always -p /opt/zimbra/data/ldap/mdb/db/data.mdb /backups/zimbra/data/ldap/mdb/db/
echo "$(date +%Y%m%d_%H%M%s) Start Zimbra.."; su - zimbra -c '/opt/zimbra/bin/zmcontrol start'

PREV_DIR=`ls -ldN zimbra.$(date +%Y)* | tail -1 | awk '{print $9}'`
DEST_DIR="zimbra.$(date +%Y%m%d%H%M)"
echo "Creating new backup directory: /backups/$DEST_DIR"
echo "Creating hard-link directory from the last backup to a new directory with today's timestamp"
cd /backups; cp -al --sparse=always $PREV_DIR/ $DEST_DIR/
echo "Performing rSync of cloned data to new backup dir, preserving hard links"
rsync -a -H --delete --inplace \
        --exclude data/ldap/mdb/db/data.mdb \
        zimbra/ $DEST_DIR/
echo "Re-Copying Sparse file from current Zimbra to new backup dir"
yes | cp --sparse=always -p /backups/zimbra/data/ldap/mdb/db/data.mdb /backups/$DEST_DIR/data/ldap/mdb/db/

# Retain ONLY 14 days worth of backups
echo "Cleaning up old backups to ensure we don't run out of space"
ls -l /backups | grep zimbra.$(date +$Y) | sort | perl -e'@x=<>;print@x[0..$#x-14]' | awk '{print "/backups/" $9}' > /tmp/toDELETE.txt
while IFS= read -r line; do
  rm -rf "$line"
done < "/tmp/toDELETE.txt"
rm -rf /tmp/toDELETE.txt