#!/bin/bash

if [ $# -lt 2 ] ; then
  echo "USAGE $0 DUMP_FILE TABLE"
  exit
fi

start=`date`

# prepare directory
rm -rf dump/
mkdir -p dump/

# optimizations
prepend="SET GLOBAL max_connections = 100;"
prepend="$prepend SET GLOBAL net_buffer_length=1000000; "
prepend="$prepend SET foreign_key_checks = 0; "
prepend="$prepend SET UNIQUE_CHECKS = 0; "
prepend="$prepend SET AUTOCOMMIT = 0; "
echo $prepend > dump/prepend.sql

append="SET foreign_key_checks = 1; "
append="$append SET UNIQUE_CHECKS = 1; "
append="$append SET AUTOCOMMIT = 1; "
append="$append COMMIT ; "
echo $append > dump/append.sql


# gunzip
gunzip -c  $1 > dump/dump.sql

# split dump
cd dump/
csplit -s -ftable dump.sql "/-- Table structure for table/" {*}

# make complite micro dumps
mv table00 head
for file in `ls -1 table*`; do
      tableName=`head -n1 $file | cut -d$'\x60' -f2`
      cat head prepend.sql $file append.sql > "$tableName.sql"
done

# cleaning
rm dump.sql prepend.sql append.sql head table*

# importing 
mysql_import(){
  mysql $2 < $1
  echo "Imported $1..."
}


for file in *; do
    mysql_import "$file" "$2" &
done

wait

# store end date to a variable
end=`date`

echo "Start import: $start"
echo "End import: $end"
