#!/bin/bash
############# START CONFIG ############
CONFIG="config.php"
if [ ! -f $CONFIG ]; then
  echo "Missing config file $CONFIG"
  exit 1
fi

#Read from env
DB_PROD_NAME="$(grep dbname $CONFIG | awk -F"'" '{print $2}')"
DB_PROD_HOST="$(grep dbhost $CONFIG | tail -1 | awk -F"'" '{print $2}')"
DB_PROD_USER="$(grep dbuser $CONFIG | awk -F"'" '{print $2}')"
DB_PROD_PASSWORD="$(grep dbpass $CONFIG | awk -F"'" '{print $2}')"
DB_BACKUP_DIRECTORY="pre-deploy-backups"

MOODLE_UPGRADE_LOG="moodle-upgrade-$(date +%d.%m.%Y-%Hh%Mm%Ss).log"

#Create also backup directory if needed
if [ ! -d $DB_BACKUP_DIRECTORY ]; then
  mkdir ${DB_BACKUP_DIRECTORY}
fi
################ END CONFIG ##########

#Only MODIFY THIS function to avoid script issues
function deploy()
{
  SHORT_STAT=$(git diff --shortstat)
  #DELAY to let a last possibility to stop
  for ((i=5;i>=1;i--));
  do
     echo "Starting deploy [${SHORT_STAT}] in $i secs (press CTRL-C to exit)"
     sleep 1
  done

  echo -e "Moodle OFFLINE\n" &&  php admin/cli/maintenance.php --enable && \
  echo -e "Backup DB\n" && mysqldump --add-drop-table -h "$DB_PROD_HOST" -u "$DB_PROD_USER" --password="$DB_PROD_PASSWORD" "$DB_PROD_NAME" | \
    gzip -v > ${DB_BACKUP_DIRECTORY}/moodle-pre-deploy-$(date +%d.%m.%Y-%Hh%Mm%Ss).sql.gz && \
  echo -e "Git PULL\n" &&  git pull && \
  echo -e "Git Submodule update\n" &&  bash ./scripts/git-sub-update-init.sh && \
  echo -e "Moodle upgrade\n" &&  php admin/cli/upgrade.php --non-interactive --verbose-settings > "$MOODLE_UPGRADE_LOG"  2>&1 && cat "$MOODLE_UPGRADE_LOG" && \
  echo -e "Moodle ONLINE\n" &&  php admin/cli/maintenance.php --disable && echo -e "\n\nYuhu ;-)"
}

function confirmDeploy()
{
  echo "#####################################"
  echo "# READY TO DEPLOY following CHANGES #"
  echo "#####################################"
  git diff --compact-summary
  echo ""

  read -r -p "Do you really want to DEPLOY this ? [y/N] " response
  case "$response" in
      [yY][eE][sS]|[yY])
          deploy
          ;;
      *)
          echo "Operation cancelled by user"
          ;;
  esac

}

#Check if script has been modified (reload if needed)
git fetch && git diff --stat | grep "$0"
LAST=$?
if [ $LAST -eq 0 ] ; then
  echo "/!\DEPLOY SCRIPT UPDATE DETECTED - UPDATING/!\ "
  #GO OFFLINE because we will do a pull which may contain something else than only deploy script update !!!
  echo -e "Moodle OFFLINE\n" &&  php admin/cli/maintenance.php --enable && \
    git pull && bash "$0" "$1" && exit 0
else
  #No changes in deploy script, we can continue with that script
  if [ "$1" = "--no-interaction" ] ; then
    deploy
  else
    confirmDeploy
  fi
fi




