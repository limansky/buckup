Buckup 2
========

  Buckup is a simple bash script to perform full or incremental file backups (using 
tar), and MySQL DB backups.

Requirements
------------

Following commands shall be available to perform backup properly:

 * `gzip` -- currently only gz archives a supported.
 * `tar` -- for files archiving.
 * `mysqlbackup` -- if you need to backup MySQL database.
 * `ftp` -- if you need to upload backup to FTP server

Usage
-----

`buckup2.sh <configfile> <mode>`

`configfile` -- setups the backup parameters.
`mode` -- full or update.  Defines if full or incremental backup is required.
          The incremental backup can be executed only if full backup was performed
          previously.

Config file format
------------------

  Config file contains set of parameters defined as: `parameter=value`

### Common options:

 * `archive_name` -- base part of all backup files. (see Files produced for more details).
 * `archive_path` -- path there archives will be created.

### File backup options:

 * `files_base_dir` -- directory there files to be archived are located (e.g. "/var/www/localhost/").
 * `files_to_archive` -- list of files and directories to be archived (e.g. "htdocs cgi-bin").
 * `files_to_exclude` -- list of files to be excluded from backup (e.g. "htdocs/tmp").

### Database backup options:

 * `mysql_databases` -- list of databases to be included in backup. If not defined, DB backup is 
                        not performed.
 * `mysql_user` -- user name to connect to DB (this user shall have read access to the DB).
 * `mysql_passwd` -- user password to connect to DB.
 * `mysql_host` -- MySQL server host name. Default: localhost.

### FTP options

 * `ftp_host` -- FTP server to upload backups host name.
 * `ftp_path` -- path on FTP server to store backups.
 * `ftp_user` -- user name to login to FTP server.
 * `ftp_passwd` -- user password to login to FTP server.

### Cleanup options

 * `local_life_time` -- amount of days to store backup files locally. If not set cleanup will not be
                        performed.  Cleanup is run only in base mode.
 * `ftp_life_time` -- amount of days to store backup files on FTP server. If not set, files will
                      not be deleted.

Files produced:
---------------
 * `archive_name-<date>-base.tar.gz` -- files archive in base mode.
 * `archive_name-<date>-base.tlst` -- list file (see `man 1 tar` `--listed-incremental` option).
 * `archive_name-<data>-upd.tar.gz` -- files archive in incremental mode.
 * `archive_name-<data>.sql.gz` -- zipped MySQL DB dump.
