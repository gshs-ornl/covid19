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
        def get_encoding_type(f):
            with open(f, 'rb') as f:
                raw = f.read()
                from_codec = get_encoding_type(f)
            return detect(raw)['encoding'], from_codec
        self.logger.info(
            f'Retrieved encoding {from_codec}, converting to utf8')
        try:
            with open(f, 'r',
                      encoding=from_codec) as f, open(target, 'w',
                                                      encoding='utf-8') as e:
                text = f.read()
                e.write(text)
            if ce('PRODUCTION', 'False') == 'True':
                os.remove(f)
            target = target + '_utf8.csv'
            os.rename(f, target)
            self.csv_utf_list = self.csv_utf_list.append(target)
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
