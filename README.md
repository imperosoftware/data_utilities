This is a a script to restore school data from one MySQL DBMS to another. It works by doing `mysqldump`s of individual tables on the source DBMS and collating them all in a single SQL script file. 
This file can then be ran on the the target DBMS, restoring the table data. 

## Setup
change the following script variables

```ruby
@db_host = <source_db_host>
@db_user = <source_db_user>
@db_name = <source_db_name>
@school_id = <school_id_to_restore>
```


## To run

```bash
$> cd <platform project directory>
$> DBPASSWD=<source_db_passwd> bin/rails runner restore_school.rb
```

this will generate a `total_dump.sql` file. Then you can run:

```bash
$> mysql -h <target_db_host> -u <target_db_user> -p -D <target_db_name> < total_dump.sql
```

This will restore all school data
