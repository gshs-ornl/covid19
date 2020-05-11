# CLI Driver for Loading Existing CSVs into the Database

## Python environment

```
python3 -m venv covidb2env
. ./covidb2env/bin/activate
pip install --upgrade pip
pip install -r ./requirements.txt
```

## Load Data from automatically scraped CSVs

```
python -u ./csv_loader.py . | tee csv_loader.$(date -Is).log

```

The script will not fail on IntegrityErrors but the errors will be reported.  If any errors are reported then the improt is likley incomplete.

