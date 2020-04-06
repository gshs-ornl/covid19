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
from cvpy.exceptions import IngestException


class Ingest():
    """Ingests all csvs in the output directory, and writes aggregate to the
       $INPUT_DIR."""

    def __init__(self, production=ce('PRODUCTION', default='False'),
                 logger=logging.getLogger(ce('PY_LOGGER', 'main'))):
        """Set up the Ingest class for ingestion of csvs."""
        self.logger = logger
        self.output_dir = ce('OUTPUT_DIR', '/tmp/output/')
        self.logger.info(f'Input directory set as {self.output_dir}')
        self.csv_list = glob.glob(self.output_dir + '*.csv')
        self.logger.info(f'Found {len(self.csv_list)} csvs to ingest')
        if production.lower() == 'true':
            self.production = True
        elif production.lower() == 'false':
            self.production = False
        else:
            raise IngestException(
                f'Unrecognized production value {production}')
        if production:
            self.aggregate_csvs()

