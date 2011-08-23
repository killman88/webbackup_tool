#!/bin/bash
###############################################
#
# Backup script via ssh/scp
#
# Author: github@openwebtech.fr
# Date: 06/08/2011
###############################################
# prerequisites :
# to be able to join the remote server and copy 
# you have to be connected via ssh without having
# to key any password
#
# ssh-keygen -t dsa; no passphrase
# ssh-copy-id -i ~/.ssh/id_dsa.pub root@host
#
# rsync has to be installed on the remote server
# SOURCES:
# http://technique.arscenic.org/transfert-de-donnees-entre/article/rsync-synchronisation-distant-de
# http://dev.mysql.com/doc/refman/5.0/fr/option-files.html
################################################
###########
# Variables
###########
# Common
PROGNAME=`basename $0`
SITE="/var/www/scuttle/" #set that manual: path of the site which has to be backed up
DEST="" # where you want to save
SRV_TO_BCK="" # login@host
sitename="scuttle-openwebtech" # this is to name the tarball
date=`date -u '+%Y%m%d'`
# dump BDD
# see README
# bdd_user; bdd_pass replaced by ~/.my.cnf
bdd_name="scuttle"
dump_flag=1
#backups cleaning
datelimit=`date -d '10 days ago' '+%Y%m%d'`
################################################
# Functions
############

# print_help
function print_help() {
	echo "$PROGNAME V1.0"
	print_usage
}

# print_usage
function print_usage() {
cat << EOF
Usage: $PROGNAME [-s] "login@host" [-d|--dest] "/dir/to/save"
       $PROGNAME [-b] [-s] "login@host" [-d|--dest] "/dir/to/save"
DESCRIPTION:
Make a backup from a specific directory into an archive date-site.tar.gz, then it is downloaded
on the backup server via ssh/scp
OPTIONS:
-h,--help : print help
-d, --dest : path to save the archive
-s : server host login@host
-b, --bdd : make a sql dump
EOF
}

# check_site
function check_site(){
$site=`ssh $SRV_TO_BCK 'if [[ -d $SITE ]]; then echo "ok";fi;'`
if [[ "$site" == "ok" ]]
then
	echo -e "Le site existe!\n"
	return 0
else
	echo -e "Le site existe pas!\n"
	return 1
fi
}

# sync_site
function sync_site() {
dir=`dirname $DEST 2>/dev/null` # check if local dir exists
if [[ (-d "$dir") && ("$DEST" != "") || ("$SRV_TO_BCK" != "") ]]
then
	echo -e "Backup de $SITE en cours...\n"
	rsync -ave ssh $SRV_TO_BCK:$SITE $DEST/$sitename #Make an incremental copy to local directory
else
	echo -e "Parameters missing or misconfigured!\n"
	exit 1
fi
}

# make_tar
function make_tar() {
echo -e "Making a $date-$sitename.tar.gz of $site...\n"
cd $DEST; tar -zcvf $date-$sitename.tar.gz $sitename # Make a tarball from the site for historization
case $? in
	2)
		echo -e "$DEST/$sitename : No such file or directory!"
		exit 1
	;;
	0)
		echo -e "Making $date-$sitename.tar.gz done!"
	;;
esac
}
# dump sql
function make_sqldump(){
if [[ ("$DEST" == "") || ("$SRV_TO_BCK" == "") ]] # checks if parameters are missing
then
	echo -e "Unable to connect mysql server, one or more parameters are missing!"
	exit 1
else
	echo -e "Making sql dump from $bdd_name...\n"
	ssh $SRV_TO_BCK "mysqldump $bdd_name>$date-$sitename-dump.sql" && scp $SRV_TO_BCK:/root/$date-$sitename-dump.sql $DEST/$date-$sitename-dump.sql
	ssh $SRV_TO_BCK "rm /root/$date-$sitename-dump.sql" # delete sql dump when finishing
	exit 0
fi
}

#############################################
#
# Traitement des parametres passes en arguments
#
##############################################
if [ $# -eq 0 ]
then
	print_help
fi

while [ "$1" != "" ]
do
case $1 in
	-h|--help)
		print_help
		exit 0
		;;
	-s)
		shift
		if [[ "$1" =~ [a-z0-9]*\@[a-z0-9]* ]] # checks remote address
		then
			SRV_TO_BCK=$1
		else
			echo "WARNING: hostname error!\n"
			print_usage
			exit 1
		fi
		shift
		;;
	-d|--dest)
		shift
		if [[ -d $1 ]]
		then
			DEST=$1
			DEST=`echo $DEST | sed -e 's/\/$//'` # substitue end / from $DEST to avoid errors
		else
			echo "Unable to backup. Directory does not exist!"
			exit 1
		fi
		shift
		;;
	-b|--bdd)
		dump_flag=0
		shift
		;;
	esac
done
############################
#
#  Main
#
############################
#backup
if [[ check_site && $dump_flag -eq 1 ]]
then
	sync_site
	make_tar
	echo -e "Backup done!\n"
	exit 0
elif [[ (check_site) && ($dump_flag -eq 0) && (`ssh $SRV_TO_BCK 'test -e /root/.my.cnf; echo $?'` -eq 0) ]]
then
	make_sqldump
	echo -e "SQL dump done!\n"
else
	echo -e ".my.cnf missing\n"
	exit 1
fi
#clean old backups
#WARNING: do not forget to set up datelimit!
for file in `ls ${DEST}/* -1`
do
        if [[ "$file" < "$datelimit" ]]
        then
        	#echo $file
        	rm -r $file
        fi
done

