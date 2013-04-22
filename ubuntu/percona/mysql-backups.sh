#!/bin/bash
#
# Script to run Percona xtrabackups

DATA_DIR=/var/lib/mysql
FULL_BACKUP_DIR=/var/tmp/backups/mysql/full
INCR_BACKUP_DIR=/var/tmp/backups/mysql/incremental

# Errors
error() {
	echo "$1" 1>&2
	exit 1
}

# Argument passed? 
if [ $# -eq 0 ]
  then
    error "No arguments supplied. Use \"full\" or \"inc\" "
fi

# Only takes one argument
act=$1

# What are we running? full, inc or tidy...
if [ $act == "full" ] 
then	
	
	# Remove previous full backup
	echo "Removing old backup files at $FULL_BACKUP_DIR/*"
	rm -rf $FULL_BACKUP_DIR/*

	# Run percona backup in full
	echo "Running new $act backup of $DATA_DIR to $FULL_BACKUP_DIR"
	xtrabackup --backup --target-dir=$FULL_BACKUP_DIR

	# Done!
	echo "Done!"

elif [ $act == "inc" ]
then
	# Use the hour as the dir name
	HOUR=$(date +%H)
	INCR_BACKUP_HOUR_DIR=$INCR_BACKUP_DIR/$HOUR

	# Does it already exist? Ditch it and start again...
	if [-d $INCR_BACKUP_HOUR_DIR]
	then 
		echo "$INCR_BACKUP_HOUR_DIR exists, removing..."
		rm -rf $INCR_BACKUP_HOUR_DIR
	fi

	# Make the directory for this hour
	echo "Making new directory for $INCR_BACKUP_HOUR_DIR"
	mkdir $INCR_BACKUP_HOUR_DIR

	# Run incremental backup off the full backup
	echo "Running $act backup at $HOUR HR of $DATA_DIR to $INCR_BACKUP_HOUR_DIR based on $FULL_BACKUP_DIR"
	xtrabackup --backup --target-dir=$INCR_BACKUP_HOUR_DIR --incremental-basedir=$FULL_BACKUP_DIR

else
	error "Invalid option. Use \"full\" or \"inc\" "
fi

exit 0
