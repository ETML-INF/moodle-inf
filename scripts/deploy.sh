#!/bin/bash
CONFIG="config.php"
if [ ! -f $CONFIG ]; then
  echo "Missing config file $CONFIG"
  exit 1
fi

DB_PROD_NAME="$(grep dbname $CONFIG | awk -F"'" '{print $2}')"
DB_PROD_HOST="$(grep dbhost $CONFIG | tail -1 | awk -F"'" '{print $2}')"
DB_PROD_USER="$(grep dbuser $CONFIG | awk -F"'" '{print $2}')"
DB_PROD_PASSWORD="$(grep dbpass $CONFIG | awk -F"'" '{print $2}')"
DB_BACKUP_DIRECTORY="pre-deploy-backups"

REPO="https://github.com/ETML-INF/moodle-inf.git"

# Init repo if needed (FIRST TIME ONLY)
# this may need be done manually...
if [ ! -d .git ]; then
  git init .
  git remote add origin ${REPO}
  git fetch
  git checkout main
fi

#Create also backup directory if needed
if [ ! -d $DB_BACKUP_DIRECTORY ]; then
  mkdir ${DB_BACKUP_DIRECTORY}
fi

#OFFLINE
echo -e "Moodle OFFLINE\n" &&  php admin/cli/maintenance.php --enable
LAST=$?
if [ $LAST -eq 0 ] ; then
  #Reload script if needed
  git fetch && git diff --stat origin/main | grep "$0"
  LAST=$?
  if [ $LAST -eq 0 ] ; then
    echo "Pull and restart updated script $0"
    git pull && bash "$0" && exit 0
  else
    echo -e "Backup DB\n" && mysqldump --add-drop-table -h "$DB_PROD_HOST" -u "$DB_PROD_USER" --password="$DB_PROD_PASSWORD" "$DB_PROD_NAME" | gzip -v > ${DB_BACKUP_DIRECTORY}/moodle-pre-deploy-$(date +%d.%m.%Y-%Hh%Mm%Ss).sql.gz && \
    echo -e "Git PULL\n" &&  git pull && \
    echo -e "Git Submodule update\n" &&  bash ./scripts/git-sub-update-init.sh && \
    echo -e "Moodle upgrade\n" &&  php admin/cli/upgrade.php --non-interactive --verbose-settings > moodle-upgrade-$(date +%d.%m.%Y-%Hh%Mm%Ss).log 2>&1 && \
    echo -e "Moodle ONLINE\n" &&  php admin/cli/maintenance.php --disable
  fi
else
  echo "Cannot go offline, stopping deploy"
fi


