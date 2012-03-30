#!/bin/bash

# Buckup version 0.3.1
# Copyright (C) 2009-2012 Mike Limansky
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

# archive file extention
ARCH_EXT="tar.gz"

# list file extention
LIST_EXT="tlst"

# mysqldump extention
DUMP_EXT="sql"

# temp file to create ftp scripts.
TMP_FILE=/tmp/buckup.$$

# Show usage message
usage()
{
	echo "buckup.sh <config_file> <mode>"
	echo -e "\t<mode> one of base, update"
}

# Put error message to STDERR and to syslog.
errorlog()
{
	echo $1 >&2
	logger -p local0.warning -t BUCKUP $1
}

infolog()
{
    echo $1
    logger -p local0.info -t BUCKUP $1
}

if [[ $# -ne 2 ]]
then
	usage
	exit 1
fi

infolog "Backup is started for $1, mode $2"

if [[ ! -f $1 ]]
then
	errorlog "Configuration file not found."
	exit 2
fi

#Default values
mysql_host="localhost"

source $1

if [[ ! -d $archive_path ]]
then
	errorlog "Archive path isn't valid or not exists."
	exit 5
fi

archive_path=${archive_path%/}

target_files=""
today=`date +%Y%m%d`

# Create file archive.
if [[ -n $files_to_archive ]]
then
	echo "Have some files to be archived."
	
	if [[ -z $archive_name ]]
	then
		errorlog "Configuration file doesn't contain archive file name."
		exit 4
	fi

	if [[ -n $files_base_dir ]]
	then
		if [[ -d $files_base_dir ]]
		then
			cd $files_base_dir
		else
			errorlog "Files base dir is not exists!"
			exit 7
		fi
	fi

	case $2 in
		base)
			echo -n "Performing base archive creation. It cat take a long time..."
			bname="$archive_path/$archive_name-$today-base"
			archive=$bname.$ARCH_EXT
			listfile=$bname.$LIST_EXT
			;;
		update)
			echo -n "Performing incremental archiving..."
			upname="$archive_path/$archive_name-$today-upd"
			archive=$upname.$ARCH_EXT
			# TODO: use find -regex
			echo "find $archive_path -maxdepth 1 -regextype posix-extended -regex "$archive_path/$archive_name-[0-9]{8}-base.$LIST_EXT" | sort -r | head -1"
			listfile=`find $archive_path -maxdepth 1 -regextype posix-extended -regex "$archive_path/$archive_name-[0-9]{8}-base.$LIST_EXT" | sort -r | head -1`
			if [[ -z "$listfile" ]]
			then
				errorlog "Listing file not found! Cannot do incremental backup!"
				exit 6
			fi
			;;
		*)
			usage
			exit 3
			;;
	esac

	if [[ -f $archive ]]
	then
		errorlog "Archive already exists! Something wrong has been occurred!"
		exit 10
	fi
	
	tarparams=$files_to_archive

	for excl in $files_to_exclude
	do
		tarparams+=" --exclude $excl"
	done

	tar czpf $archive -g $listfile $tarparams
	echo " Done"

	target_files="$archive $listfile"
fi

# Dump databases
if [[ -n $mysql_databases ]]
then
	echo -n "Creating DB dump..."
	dumpname="$archive_path/$archive_name-$today.$DUMP_EXT"

	if mysqldump -u$mysql_user -p$mysql_passwd -h$mysql_host --databases $mysql_databases > $dumpname
	then
		echo " Done"
		echo -n "Gzipping the dump..."
		gzip $dumpname
		echo " Done"
		target_files+=" $dumpname.gz"
	else
		echo " Failed"
		errorlog "Unable to dump DB"
	fi
fi

# Upload on FTP
if [[ -n $ftp_host && -n $target_files ]]
then
	echo -n "Uploading to FTP..."
	echo "quote USER $ftp_user
quote PASS $ftp_passwd
binary" > $TMP_FILE

	if [[ -n $ftp_path ]]
	then
		echo "cd $ftp_path" >> $TMP_FILE
	fi

	echo "lcd $archive_path" >> $TMP_FILE

	for f in $target_files
	do
		echo "put ${f##*/}" >> $TMP_FILE
	done

	echo "quit" >> $TMP_FILE

	ftp -n $ftp_host < $TMP_FILE
	rm $TMP_FILE
	echo " Done"
fi

# Cleanup local backup dir
if [[ -n $local_life_time && $2 = "base" ]]
then
	echo -n "Cleaning the buckup directory..."
	find $archive_path -maxdepth 1 -name "$archive_name-[0-9]*" -mtime +$local_life_time -print -delete
	echo " Done"
fi 

# Cleanup remote backup dir
if [[ -n $ftp_host && -n $ftp_life_time && $2 = "base" ]]
then
	echo -n "Removing outdated files from FTP..."
	echo "quote USER $ftp_user
quote PASS $ftp_passwd
ls $ftp_path" > $TMP_FILE

	file_list=`ftp -n $ftp_host < $TMP_FILE | grep "$archive_name-[0-9]\{8\}"`

		echo "quote USER $ftp_user
quote PASS $ftp_passwd" > $TMP_FILE

	if [[ -n $ftp_path ]]
	then
		echo "cd $ftp_path" ]] >> $TMP_FILE
	else
		echo "" >> $TMP_FILE
	fi

	OLDIFS=$IFS
	IFS=$'\n'

	for line in $file_list
	do
		filename=`echo $line | awk '{ print $9 }'`
		timestamp=${filename:${#archive_name}+1:8}
		dt=$(( (`date +%s` - `date -d $timestamp +%s`) / 3600 / 24 ))
		if [[ $dt -gt $ftp_life_time ]]
		then
			echo "delete $filename" >> $TMP_FILE
		fi
	done

	IFS=$OLDIFS

	echo "quit" >> $TMP_FILE

	ftp -n $ftp_host < $TMP_FILE
	rm $TMP_FILE
	echo " Done"
fi

infolog "Backuping is complete for $1, mode $2"
