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

