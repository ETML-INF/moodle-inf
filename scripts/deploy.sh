#!/bin/bash
DB_PROD_NAME="$(grep dbname config.php | awk -F"'" '{print $2}')"
DB_PROD_HOST="$(grep dbhost config.php | awk -F"'" '{print $2}')"
DB_PROD_USER="$(grep dbuser config.php | awk -F"'" '{print $2}')"
DB_PROD_PASSWORD="$(grep dbpass config.php | awk -F"'" '{print $2}')"

REPO="https://github.com/ETML-INF/moodle-inf.git"

#disable site
php admin/cli/maintenance.php --enable

# Init repo if needed
if [ ! -d .git ]; then
  git init .
  git remote add origin ${REPO}
  git fetch
  git checkout main
fi

#DB Backup
mysqldump --add-drop-table -h $DB_PROD_HOST -u $DB_PROD_USER --password=$DB_PROD_PASSWORD $DB_PROD_NAME > pre-deploy-backups/moodle-pre-deploy-$(date +%Y%m%d%-H%M%S).sql

#Update git
git pull
./git-sub-update-init.sh

#Update moodle
php admin/cli/upgrade.php

#Activate site
php admin/cli/maintenance.php --disable
