#!/usr/bin/env python3
"""Contains methods for slurping data from the $INPUT_DIR into the database."""
import os
import logging
import traceback
from cvpy.database import Database
from cvpy.common import check_environment as ce
from cvpy.common import glob_csvs, get_csv, create_uri
from cvpy.errors import SlurpError


class Slurp():
    """Slurps an $CLEAN_DIR CSV into the database and creates views."""

    def __init__(self, csv=None, clean_dir=ce('CLEAN_DIR', '/tmp/clean'),
                 logger=logging.getLogger(ce('PY_LOGGER', 'main')),
                 view_creator=ce('VIEW_CREATOR', 'create_views.sql')):
        """Initialize the Slurp."""
        self.view_creator = view_creator
        self.logger = logger
        self.uri = create_uri(self.logger)
        self.csv = csv
        if self.csv is None:
            csvs = glob_csvs(clean_dir, self.logger)
            for c in csvs:
                if os.path.exists(c):
                    df = get_csv(c, self.logger)
                    self.process(df, c)
                else:
                    self.logger.warning(f'File {c} was not found, skipping.')
        else:
            if os.path.exists(self.csv):
                df = get_csv(c, self.logger)
                self.process(df, c)

    def process(self, df, c):
        """Process the CSV passed during Slurp initialization."""
        # TODO fill in with better logic
        self.logger.info(f'Proceeding with file {self.csv}')
        try:
            with Database() as db:
                db.insert_raw_data(df)
            os.remove(c)
        # TODO better exception handling
        except OSError as e:
            traceback.print_stack()
            self.logger.error(f'File removal issue for {c}: {e}')
        except Exception as e:
            traceback.print_stack()
            self.logger.error(f'Problem slurping {c}: {e}')
            raise SlurpError(f'Slurper: {c}',
                             'Slurping of CSV failed with error: {e}')
