#!/bin/bash
#
# Zimbra Rocks! Backup Script
# License: GPL3 
#
# A better rSync backup script.. efficiently utilizing hard links to create daily snapshots
#  - Performs Per-Account, Per-Service (LDAP & MYSQL), and full cold backup of Zimbra installation directory
#  - Utilizes an efficient-method to keep hard downtime to minutes
#  - Sparse MDB file properly handled
#  - Built-In Fix for zmcontrol not starting services back up cleanly. Significantly increases reliability.
#  - Retention customizable based on number of days
#  - Customizable output to control where to send script output
#
# Your Zimbra user. Generally, you shouldn't need to modify this.
export ZIMBRA_USER=zimbra
# The directory that your Zimbra is installed to. 
export ZIMBRA_INSTALL_DIR=/opt/zimbra
# This is the directory that you want your backups stored in
export ZIMBRA_BACKUP_DIR=/zimbra-backups
# Perform Full Cold Backup of Zimbra. This does require stopping Zimbra. 
# But due to design, the actual backup should only take a minute or two.
export BACKUP_FULL=1
# The number of days to retain backups
export DAYS_TO_RETAIN=14
# Where to send output from this script
# If you aren't using this script with docker, you should set this to a .log file path
export LOG_OUTPUT=$DOCKER_SYSTEMLOGS
# Where you'd like your LDAP, MySQL, and Per-Account Backups Stored
# This should either be $ZIMBRA_INSTALL_DIR or $ZIMBRA_BACKUP_DIR/zimbra to ensure they are backed up
# In general, there probably isn't much reason to modify this.
export ONEOFF_BACKUP_DIR=$ZIMBRA_BACKUP_DIR/zimbra
# Perform One-Off Backup of LDAP, without taking Zimbra offline
export BACKUP_LDAP=1
# Perform One-Off Backup of MYSQL, without taking Zimbra offline
export BACKUP_MYSQL=1
# Perform One-Off Backup of Mailbox Accounts, without taking Zimbra offline
export BACKUP_ACCOUNTS=0
#
#######################################
#######################################
# You should not need to modify any code below this line.

if [[ $EUID -ne 0 ]]; then echo "This script must be run as root"; exit 1; fi
# Function to standardize log entry format
function log_entry { 
  echo "$(date +%F_%T) zimbra-backup: $1" >> $LOG_OUTPUT 
}

# SANITY CHECKS OF VARIABLE VALUES
[[ `type rsync | grep -v hashed` != "" ]] && (log_entry "RSYNC MISSING"; exit 1;)
[[ `getent passwd $ZIMBRA_USER` == "" ]] && (log_entry "BAD ZIMBRA_USER"; exit 1;) 
[[ ! -d "$ZIMBRA_INSTALL_DIR" ]] && (log_entry "BAD ZIMBRA_INSTALL_DIR"; exit 1;)
[[ ! -d "$ZIMBRA_BACKUP_DIR" ]] && (log_entry "BAD ZIMBRA_BACKUP_DIR"; exit 1;)
[[ $LOG_OUTPUT == "" ]] && (log_entry "BAD LOG_OUTPUT"; exit 1;)
if [[ "$ONEOFF_BACKUP_DIR" != "$ZIMBRA_INSTALL_DIR" ]] && [[ "$ONEOFF_BACKUP_DIR" != "$ZIMBRA_BACKUP_DIR/zimbra" ]]; then
  log_entry "BAD ONEOFF_BACKUP_DIR";
  exit 1;
fi

log_entry "***************************************"
log_entry "***************************************"
log_entry "BEGINNING ZIMBRA BACKUP"

if [[ $BACKUP_FULL == 1 ]]; then
  # Perform initial rsync of Zimbra first to minimize how long we need to have services stopped
  log_entry "Perform initial LIVE rsync of $ZIMBRA_INSTALL_DIR to $ZIMBRA_BACKUP_DIR/zimbra"
  /usr/bin/rsync --delete --delete-excluded -a \
          --exclude data/amavisd/ \
          --exclude data/clamav/ \
          --exclude data/tmp \
          --exclude data/mailboxd/imap-inactive-session-cache.data \
          --exclude zmstat \
          --exclude data.mdb \
          $ZIMBRA_INSTALL_DIR/* $ZIMBRA_BACKUP_DIR/zimbra
fi

# Perform One-Off backup of LDAP
if [[ $BACKUP_LDAP == 1 ]]; then
  log_entry "Take manual LDAP backup and store within Zimbra's Installation Directory"
  # Create directory if it doesn't exist
  if [[ ! -d "$ONEOFF_BACKUP_DIR" ]]; then su - $ZIMBRA_USER -c "mkdir $ONEOFF_BACKUP_DIR"; fi
  if [[ ! -d "$ONEOFF_BACKUP_DIR/ldap-backup" ]]; then su - $ZIMBRA_USER -c "mkdir $ONEOFF_BACKUP_DIR/ldap-backup"; fi
  su - $ZIMBRA_USER -c "$ZIMBRA_INSTALL_DIR/libexec/zmslapcat -c $ONEOFF_BACKUP_DIR/ldap-backup/"
  su - $ZIMBRA_USER -c "$ZIMBRA_INSTALL_DIR/libexec/zmslapcat $ONEOFF_BACKUP_DIR/ldap-backup/"
fi

# Perform One-Off backup of MySQL
if [[ $BACKUP_MYSQL == 1 ]]; then
  # Obtain path to mysqldump. Apparently different versions of Zimbra store this in different locations
  MYSQLDUMP_PATH=`find $ZIMBRA_INSTALL_DIR -name mysqldump | tail -1`
  # As long as we found a mysqldump, then we can proceed to take MySQL backup
  if [[ $MYSQLDUMP_PATH != "" ]]; then
    log_entry "Take Backup of MySQL DB and store within Zimbra's Installation Directory"
    # Create directory if it doesn't exist
    if [[ ! -d "$ONEOFF_BACKUP_DIR" ]]; then su - $ZIMBRA_USER -c "mkdir $ONEOFF_BACKUP_DIR"; fi
    if [[ ! -d "$ONEOFF_BACKUP_DIR/mysql-backup" ]]; then su - $ZIMBRA_USER -c "mkdir $ONEOFF_BACKUP_DIR/mysql-backup"; fi
    su - $ZIMBRA_USER -c "source $ZIMBRA_INSTALL_DIR/bin/zmshutil; zmsetvars; \
      $MYSQLDUMP_PATH --user=root --password=\$mysql_root_password \
      --socket=\$mysql_socket --all-databases --single-transaction --flush-logs;" \
      | gzip > $ONEOFF_BACKUP_DIR/mysql-backup/mysqldump.sql.gz
  fi
fi

# Perform One-Off backup of all mailbox accounts
if [[ $BACKUP_ACCOUNTS == 1 ]]; then
  log_entry "Take backup of accounts individually"
  # Create directory if it doesn't exist
  if [[ ! -d "$ONEOFF_BACKUP_DIR" ]]; then su - $ZIMBRA_USER -c "mkdir $ONEOFF_BACKUP_DIR"; fi
  if [[ ! -d "$ONEOFF_BACKUP_DIR/mailbox-backup" ]]; then su - $ZIMBRA_USER -c "mkdir $ONEOFF_BACKUP_DIR/mailbox-backup"; fi
  # Loop through all mailbox accounts
  for account in `su - $ZIMBRA_USER -c 'zmprov -l gaa | sort'`
  do
    # Perform mailbox backup to .tgz file
    sudo -u $ZIMBRA_USER $ZIMBRA_INSTALL_DIR/bin/zmmailbox -z -m $account getRestURL "//?fmt=tgz" > $ONEOFF_BACKUP_DIR/mailbox-backup/$account.tgz
    # Examine the size of the mailbox backup file created
    TAR_SIZE=`stat --printf="%s" $ONEOFF_BACKUP_DIR/mailbox-backup/$account.tgz`
    log_entry "Processed mailbox $account backup...$TAR_SIZE bytes"
  done
fi

if [[ $BACKUP_FULL == 1 ]]; then
  # Clone Zimbra install to $ZIMBRA_BACKUP_DIR. This is necessary in case /zimbra-backups is stored on alternate storage.
  # This is the safest approach due to use of hard-linking
  log_entry "STOPPING ZIMBRA.."
  su - $ZIMBRA_USER -c "$ZIMBRA_INSTALL_DIR/bin/zmcontrol stop"
  $ZIMBRA_INSTALL_DIR/libexec/zmfixperms; # Fix all Zimbra Permissions
  # Make *SURE* all Zimbra processes are killed. A hung process would mean on restart that hung service may not restart cleanly.
  if [[ `ps awwux | grep $ZIMBRA_USER | grep -v grep` ]]; then pkill -u zimbra; fi
  log_entry "Performing FULL rsync of $ZIMBRA_INSTALL_DIR to $ZIMBRA_BACKUP_DIR/zimbra"
  /usr/bin/rsync --delete-excluded -a \
          --exclude data/amavisd/ \
          --exclude data/clamav/ \
          --exclude data/tmp \
          --exclude data/mailboxd/imap-inactive-session-cache.data \
          --exclude zmstat \
          --exclude data.mdb \
          $ZIMBRA_INSTALL_DIR/* $ZIMBRA_BACKUP_DIR/zimbra
  # Copy the data.mdb sparse file separately, to ensure it is copied as a sparse file
  log_entry "Performing sparse copy of data.mdb file from $ZIMBRA_INSTALL_DIR to $ZIMBRA_BACKUP_DIR/zimbra"
  yes | cp --sparse=always -p $ZIMBRA_INSTALL_DIR/data/ldap/mdb/db/data.mdb $ZIMBRA_BACKUP_DIR/zimbra/data/ldap/mdb/db/
  # Start LDAP first, to avoid zmcontrol service startup issues related to LDAP.
  # This is the core-fix for reliability issues that many other Zimbra backup scripts encounter.
  # Through hundreds of builds and tests, I've discovered that sometimes (random, as far as I can tell), 
  #  services fail to restart properly. It appears the cause for this is ldap not starting cleanly from
  #  zmcontrol. The easiest fix is to simply start SLAPD (ldap) before you issue the zmcontrol start.
  log_entry "Starting LDAP service (fix for clumsy zmcontrol design)"
  su - $ZIMBRA_USER -c "$ZIMBRA_INSTALL_DIR/bin/ldap start"; 
  # Issue fully restart to restart all services
  log_entry "Initiating the start of Zimbra"
  su - $ZIMBRA_USER -c "$ZIMBRA_INSTALL_DIR/bin/zmcontrol start"; 
  log_entry "ZIMBRA STARTED"
  # Ensure all services started back up before we proceed with backup
  SERVICE_CHECK=`su - $ZIMBRA_USER -c 'zmcontrol status | grep Stopped'`
  if [[ $SERVICE_CHECK != "" ]]; then
    log_entry "Stopping Zimbra a Second Time.."
    $ZIMBRA_INSTALL_DIR/libexec/zmfixperms; # Fix all Zimbra Permissions
    # Stop all services, then give an extra pause for caution
    su - $ZIMBRA_USER -c "zmcontrol stop && sleep 5"
    # Make *SURE* all Zimbra processes are killed. A hung process would mean on restart it would not start cleanly.
    if [[ `ps awwux | grep $ZIMBRA_USER | grep -v grep` ]]; then pkill -u $ZIMBRA_USER; fi
    log_entry "Re-Starting Zimbra a Second Time.."
    su - $ZIMBRA_USER -c "zmcontrol start"
    # Check to make sure there are no 'Stopped' services. If there are, we should terminate this backup run!
    SERVICE_CHECK=`su - $ZIMBRA_USER -c 'zmcontrol status | grep Stopped'`
    if [[ $SERVICE_CHECK != "" ]]; then
      log_entry "STOPPING EXECUTION DUE TO SERVICES NOT STARTING BACK UP CLEANLY"
      exit 1
    fi
  fi
fi

# Obtain the name of the previously created zimbra backup directory.
PREV_DIR=`find $ZIMBRA_BACKUP_DIR -mindepth 1 -maxdepth 1 -type d -name "zimbra.$(date +%Y)*" | tail -1`
DEST_DIR="zimbra.$(date +%Y%m%d%H%M)"
log_entry "Creating new backup directory: $ZIMBRA_BACKUP_DIR/$DEST_DIR"
# Create copy of the hard-linked previous backup directory
# This is where the magic of small daily backups happens
if [[ $PREV_DIR != "" ]]; then
  log_entry "Creating hard-link directory from $PREV_DIR to a new directory: $DEST_DIR"
  cp -al --sparse=always $PREV_DIR/ $ZIMBRA_BACKUP_DIR/$DEST_DIR/
  # Delete the daily one-off backups to ensure we aren't hard linking them day-to-day
  rm -rf $ZIMBRA_BACKUP_DIR/$DEST_DIR/*-backup
fi
# Now that we have have a copy of yesterday's hard-linked backup directory, we will rsync over it
# the current copy of the Zimbra install stored locally with the backups. This will update any new
# files so that they are hard-linked into this new directory. The result is the new directory will
# only be the size of the difference in data change between yesterday and today. e.g. differential
log_entry "Performing rSync of cloned data to new backup dir, preserving hard links"
rsync -a -H --delete --inplace --exclude data.mdb $ZIMBRA_BACKUP_DIR/zimbra/ $ZIMBRA_BACKUP_DIR/$DEST_DIR/
log_entry "Re-Copying Sparse data.mdb file from current Zimbra ($ZIMBRA_BACKUP_DIR/zimbra) to new backup dir ($ZIMBRA_BACKUP_DIR/$DEST_DIR)"
yes | cp --sparse=always -p $ZIMBRA_BACKUP_DIR/zimbra/data/ldap/mdb/db/data.mdb $ZIMBRA_BACKUP_DIR/$DEST_DIR/data/ldap/mdb/db/

log_entry "Cleaning up old backups to ensure we don't run out of space"
# Locate all directories older than $DAYS_TO_RETAIN days
find $ZIMBRA_BACKUP_DIR -mindepth 1 -maxdepth 1 -type d -name "zimbra.$(date +%Y)*" | sort | head -n -$DAYS_TO_RETAIN > /tmp/toDELETE.txt
# Loop through these located directories and remove them
while IFS= read -r line; do if [[ $line != "" ]]; then echo "DELETING: $line"; rm -rf "$line"; fi done < "/tmp/toDELETE.txt"; 
log_entry "COMPLETED ZIMBRA BACKUP"
log_entry "***************************************"
log_entry "***************************************"