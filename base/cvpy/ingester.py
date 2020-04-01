#!/usr/bin/env python3
"""The ingester imports all csvs in the output directory."""
import os
import glob
import logging
import traceback
import pandas as pd
from chardet import detect
from cvpy.database import Database as DB
from cvpy.common import check_environment as ce
from cvpy.static import Headers as H


class Ingest():
    """Ingests all csvs in the output directory."""

    def __init__(self, production=ce('PRODUCTION', default='False'),
                 logger=logging.getLogger(ce('PY_LOGGER', 'main'))):
        """Set up the Ingest class for ingestion of csvs."""
        self.logger = logger
        self.output_dir = ce('OUTPUT_DIR', '/tmp/output/')
        self.csv_list = glob.glob(self.output_dir + '*.csv')
        self.make_csvs_utf()
        self.uri = 'postgresql+psycopg2://ingester:AngryMoose@covidb'
        self.csv_utf_list = []

    def make_csvs_utf(self):
        """Ensure CSVs are utf8."""
        for c in self.csv_list:
            try:
                with open(c, 'rb') as f:
                    content_bytes = f.read()
                detected = chardet.detect(content_bytes)
            except UnicodeDecodeError as e:
                self.logger.error(f'Unicode Decoding error {e}')
            except UnicodeEncodeError as e:
                self.logger.error(f'Unicode Encoding error {e}')

    def combine_csvs(self, utf=True):
        df_list = []
        for f in self.utf8_csv_list:
            df = pd.read_csv(f, na_values=['na', 'null', ''],
                             keep_default_na=True)
            df_list.append(df)
        self.df = pd.concat(df_list, axis-0, ignore_index=True)

    def write_raw_to_db(self):
        if not hasattr(self, 'df'):
            self.combine_csvs()
        try:
            SUCCESS = True
            with DB() as db:
                db.insert_raw_data(self.df, self.uri)
        except Exception as e:
            SUCCCES = False
            traceback.print_stack()
            self.logger.error(f'Writing to database encountered a problem {e}')
        return SUCCESS
