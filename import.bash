#!/bin/bash

# CLI
show_help() {
  echo "Usage $0 -f DUMP_FILE -d STRING [-a ASYNC_TABLE_NAMES] [-r REPLACE_FROM] [-t REPLACE_TO]"
  echo "Example: $0 -f backup.sql.gz -d booking -a table_name|table2_name -f incorrect -t correct"
  exit 1
}

start=`date`
dumpFile=''
dbName=''
asyncImports=''
replaceFrom=''
replaceTo=''

while getopts ":f:d:a:r:t:" opt; do
    case $opt in
        h)
            show_help
            exit 0
            ;;
        f)  dumpFile=$OPTARG
            ;;
        d)  dbName=$OPTARG
            ;;
        a)  asyncImports=$OPTARG
            ;;
        r)  replaceFrom=$OPTARG
            ;;
        t)  replaceTo=$OPTARG
            ;;
        \? ) echo "Invalid option: $OPTARG" 1>&2
            show_help >&2
            ;;
        : )  echo "Invalid option: $OPTARG requires an argument" 1>&2
            show_help >&2
            ;;  
    esac
done

shift $((OPTIND -1))

if [[ -z "${dumpFile}" ]]; then
    echo "-d is required"
    show_help
fi

if test ! -f "$dumpFile"; then
    echo "$1 does not exists"
fi

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

cd dump/

# unpack
gzip -dc ../${dumpFile} | csplit -s -ftable - "/-- Table structure for table/" {*} 

replaceInFile() {
  if [[ ! -z "${replaceFrom}" ]] &&  [[ $replaceFrom != $replaceTo ]]; then
    sed -i "s/$replaceFrom/$replaceTo/" $1
  fi
}

# make complite micro dumps
mv table00 head
for file in `ls -1 table*`; do
  tableName=`head -n1 $file | cut -d$'\x60' -f2`
  cat head prepend.sql $file append.sql > "$tableName.sql"
  replaceInFile "$tableName.sql"
done

# cleaning
rm ../dump.sql prepend.sql append.sql head table*

# importing 
mysql_import(){
  mysql $2 < $1
}

for file in *; do
    mysql_import "$file" "$dbName" &

    tableName=${file%".sql"}
    if [[ -z "$asyncImports" ]] || [[ ! "$tableName" =~ $asyncImports ]]; then
      pids+=($!)
    fi
done

wait "${pids[@]}" 

# store end date to a variable
end=`date`

rm -rf ../dump

echo "Some parts of the dump will be imported in background. "
