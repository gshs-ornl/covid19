# CLI Driver for Loading Existing CSVs into the Database

## Python environment

```
python3 -m venv covidbenv
. ./covidbenv/bin/activate
pip install --upgrade pip
pip install -r ./base/db-requirements.txt
(cd base && python setup.py install)
```

## Load Data from automatically scraped CSVs

```
python -u ./bin/load_csv.py -vv ../covidb-data/daily_raw_dump/*.zip | tee csv_loader.$(date -Is).log

```

The script will not fail on IntegrityErrors but the errors will be reported.  If any errors are reported then the improt is likley incomplete.

To see all option run

```
python -u ./bin/load_csv.py -h

