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

SHA=$1
if [ -z "$SHA" ] || [ "$SHA" = "--help" ] ; then
  echo "Usage: deploy.sh <SHA> [--no-interaction]"
  exit 1
fi
NO_INTERACTION=$2

#BRANCH="main"
################ END CONFIG ##########

function reviewAndDelay()
{
    SHORT_STAT=$(git diff --shortstat "$SHA")

    echo -n "Starting deploy [${SHORT_STAT} @ ${SHA}] in (press CTRL-C to cancel) : "

    #DELAY to let a last possibility to stop
    for ((i=5;i>=1;i--));
    do
       echo -n "$i "
       sleep 1
    done
    echo -e "\nGO GO GO"
}

#MAIN BUSINESS
#Only MODIFY THIS function to avoid script issues
function deploy()
{
  reviewAndDelay

  echo -e "Moodle OFFLINE\n" &&  php admin/cli/maintenance.php --enable && \
  echo -e "Backup DB\n" && mysqldump --add-drop-table -h "$DB_PROD_HOST" -u "$DB_PROD_USER" --password="$DB_PROD_PASSWORD" "$DB_PROD_NAME" | \
    gzip -v > ${DB_BACKUP_DIRECTORY}/moodle-pre-deploy-$(date +%d.%m.%Y-%Hh%Mm%Ss).sql.gz && \
  echo -e "Git merge\n" && git merge --ff-only "$SHA" && \
  echo -e "Git Submodule update\n" &&  bash ./scripts/git-sub-update-init.sh && \
  echo -e "Moodle upgrade\n" &&  php admin/cli/upgrade.php --non-interactive --verbose-settings > "$MOODLE_UPGRADE_LOG"  2>&1 && cat "$MOODLE_UPGRADE_LOG" && \
  echo -e "Moodle ONLINE\n" &&  php admin/cli/maintenance.php --disable && echo -e "\n\nYuhuuu ;-)"
}
##END MAIN BUSINESS

function confirmDeploy()
{
  echo "######################################################################################"
  echo "# READY TO DEPLOY following CHANGES for rev ${SHA} #"
  echo "######################################################################################"
  git diff "$SHA" --compact-summary

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

#Check if script has been modified (checkout and start other version... which has another path so $0 won’t match a second time)
#Remove ./ if present to match git diff and detect if script has been modified
DEPLOY_SCRIPT_CLEAN=$(echo "$0"| sed -e s~^\./~~)
UPDATED_REPO=".repo-$SHA"
echo "Fetching origin" && git fetch && git diff --stat "$SHA" | grep "$DEPLOY_SCRIPT_CLEAN"
LAST=$?
if [ $LAST -eq 0 ]; then
  echo "/!\DEPLOY SCRIPT UPDATE DETECTED - RUNNING UPDATED VERSION/!\ "
  git worktree add -q "$UPDATED_REPO" "$SHA" && \
    bash "$UPDATED_REPO/$0" "$@" && git worktree remove "$UPDATED_REPO"
else
  #No changes in deploy script, we can continue with that script
  if [ "$NO_INTERACTION" = "--no-interaction" ] ; then
    deploy
  else
    confirmDeploy
  fi
fi
