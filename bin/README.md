# CLI Driver for Loading Existing CSVs into the Database

## Python environment

```
python3 -m venv covidbenv
. ./covidbenv/bin/activate
pip install --upgrade pip
pip install -r ./bin/requirements.txt
```

## Load Data from automatically scraped CSVs

```
python -u ./bin/csv_loader.py -vv ../covidb-data/daily_raw_dump/*.zip | tee csv_loader.$(date -Is).log

```

The script will not fail on IntegrityErrors but the errors will be reported.  If any errors are reported then the improt is likley incomplete.

To see all option run

```
python -u ./bin/csv_loader.py -h

