#!/bin/bash

# checks
if [ $# -lt 2 ] ; then
  echo "Usage $0 DUMP_FILE TABLE_NAME [TABLE_NAMES_ASYNC]"
  echo "   Example of TABLE_NAMES_ASYNC: table_name|table2_name "
  exit
fi

if ! command -v pv &> /dev/null
then
    echo "Please install pv: yum install pv"
    exit
fi

if test ! -f "$1"; then
    echo "$1 does not exists"
    exit
fi

exclude=$3 # TABLE_NAMES_ASYNC

start=`date`

# prepare directory
rm -rf dump/
mkdir -p dump/

# optimizations
prepend="SET GLOBAL max_connections = 200;"
prepend="$prepend SET UNIQUE_CHECKS = 0; "
prepend="$prepend SET AUTOCOMMIT = 0; "
echo $prepend > dump/prepend.sql

append="SET UNIQUE_CHECKS = 1; "
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
  pv --name $1 $1 | mysql $2
}

for file in *; do
    mysql_import "$file" "$2" &

    tableName=${file%".sql"}
    if [[ -z "$exclude" ]] || [[ ! $tableName =~ "$exclude" ]]; then
      pids+=($!)
    else
      echo "$tableName running async";
    fi
done

wait "${pids[@]}" 

# store end date to a variable
end=`date`

rm -rf dump

echo "Start time: $start"
echo "End time: $end"
