# MySQL Fast Import

## Usage

```bash
$ curl https://raw.githubusercontent.com/apliteni/mysql-fast-import/main/import.bash > import

$ bash ./import -f backup.sql.gz -d booking -a table_name|table2_name -f incorrect -t correct
```
