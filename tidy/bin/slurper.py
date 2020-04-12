#!/usr/bin/env python3
"""Slurp in the CSVs in the output directory."""
import logging
import pandas as pd
from glob import glob
from cvpy.common import check_environment as ce
from cvpy.common import create_uri
from cvpy.logging import DictLogger
from cvpy.database import Database

# get the standard cvpy logger
logger = logging.getLogger(DictLogger.SIMPLE)
# assign the output directory
OUTPUT_DIR = ce('OUTPUT_DIR', '/tmp/output')


def insert_csv(csv, db):
    """Insert the CSVs into the database object."""
    df = pd.read_csv(csv, na_values=['NA', '<NA>', '', ' '],
                     keep_default_na=True)
    uri = create_uri()
    logger.info(f'Created URI: {uri}')
    db.insert_raw_data(df, uri)


if __name__ == "__main__":
    csv_list = glob(f"{OUTPUT_DIR}/*.csv")
    logger.info(f'Found {len(csv_list)} CSVs to slurp into database')
    with Database() as d:
        for csv_file in csv_list:
            insert_csv(csv_file, d)
