Buckup 2
========

  Buckup is a simple bash script to perform full or incremental file backups (using 
tar), and MySQL DB backups.  Assume that only one DB is associated with one file set.

Requirements
------------

Following commands shall be available to perform backup properly:
 * gzip -- currently only gz archives a supported.
 * tar -- for files archiving.
 * mysqlbackup -- if you need to backup MySQL database.
 * ftp -- if you need to upload backup to FTP server

Usage
-----

`buckup2.sh <configfile> <mode>`

`configfile` -- setups the backup parameters.
`mode` -- full or update.  Defines if full or incremental backup is required.
          The incremental backup can be executed only if full backup was performed
          previously.
