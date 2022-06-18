#!/bin/bash
DB_PROD_NAME="$(grep dbname config.php | awk -F"'" '{print $2}')"
DB_PROD_HOST="$(grep dbhost config.php | awk -F"'" '{print $2}')"
DB_PROD_USER="$(grep dbuser config.php | awk -F"'" '{print $2}')"
DB_PROD_PASSWORD="$(grep dbpass config.php | awk -F"'" '{print $2}')"
DB_BACKUP_DIRECTORY="pre-deploy-backups"

REPO="https://github.com/ETML-INF/moodle-inf.git"

# Init repo if needed (FIRST TIME ONLY)
# this may be done manually...
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

#Upgrade...
echo -e "Moodle OFFLINE\n" &&  php admin/cli/maintenance.php --disable && \
echo -e "Backup DB\n" && mysqldump --add-drop-table -h $DB_PROD_HOST -u $DB_PROD_USER --password=$DB_PROD_PASSWORD $DB_PROD_NAME | gzip -v > ${DB_BACKUP_DIRECTORY}/moodle-pre-deploy-$(date +%Y%m%d%-H%M%S).sql.gz && \
echo -e "Git PULL\n" &&  git pull && \
echo -e "Git Submodule update\n" &&  bash ./scripts/git-sub-update-init.sh && \
echo -e "Moodle upgrade\n" &&  php admin/cli/upgrade.php --non-interactive && \
echo -e "Moodle ONLINE\n" &&  php admin/cli/maintenance.php --disable
