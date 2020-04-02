#!/usr/bin/env python3
"""Slurp in the CSVs in the output directory."""
import logging
import pandas as pd
from glob import glob
from cvpy.common import check_environment as ce
from cvpy.logging import DictLogger
from cvpy.database import Database

# get the standard cvpy logger
logging.getLogger(DictLogger.SIMPLE)
# assign the output directory
OUTPUT_DIR = ce('OUTPUT_DIR', '/tmp/output')
DB_USER = ce('DB_USER', 'digester')
DB_PASS = ce('DB_PASS', 'LittlePumpkin')
DB_URI = ce('DB_URI', f'postgres:://{DB_USER}:{DB_PASS}@


def insert_csv(csv, db):
    """Insert the CSVs into the database object."""
    df = pd.read_csv(csv, na_values=['NA', '<NA>', '',],
                     keep_default_na=True)
    db.insert_raw_data(df, DB_URI)


if __name__ == "__main__":
    csv_list = glob(f"{OUTPUT_DIR}/*.csv")
    logging.info(f'Found {len(csv_list)} CSVs to parse')
    with Database() as d:
        for csv_file in csv_list:
            insert_csv(csv_file, d)
