#!/usr/bin/env python3
"""Contains methods for slurping data from the $INPUT_DIR into the database."""
import os
import logging
import traceback
from subprocess import check_output
from cvpy.database import Database
from cvpy.common import check_environment as ce
from cvpy.common import glob_csvs, get_csv, create_uri
from cvpy.exceptions import SlurpException


class Slurp():
    """Slurps an $CLEAN_DIR CSV into the database and creates views."""

    def __init__(self, path=None, clean_dir=ce('OUTPUT_DIR', '/tmp/output'),
                 logger=logging.getLogger(ce('PY_LOGGER', 'main')),
                 view_creator=ce('VIEW_CREATOR', 'create_views.sql')):
        """Initialize the Slurp."""
        self.view_creator = view_creator
        self.logger = logger
        self.uri = create_uri(self.logger)
        self.path = path
        self.logger.info(f'Path passed: {self.path}')
        if self.path is None:
            csvs = glob_csvs(clean_dir, self.logger)
            for c in csvs:
                if os.path.exists(c):
                    df = get_csv(c, self.logger)
                    self.process(df, c)
                else:
                    self.logger.warning(f'File {c} was not found, skipping.')
        elif os.path.isdir(self.path):
            if os.path.exists(self.path):
                csvs = glob_csvs(clean_dir, self.logger)
                for c in csvs:
                    df = get_csv(c, self.logger)
                    self.process(df, c)
        elif os.path.isfile(self.path):
            df = get_csv(self.path, self.logger)
            self.process(df, self.path)
        else:
            traceback.print_stack()
            raise SlurpException(f'Unknown way to process: {self.path}')

    def process(self, df, c):
        """Process the CSV passed during Slurp initialization."""
        # TODO fill in with better logic
        self.logger.info(f'Proceeding with file {self.path}')
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
            raise SlurpException(f'Slurper: {e}' +
                                 f'Slurping of CSV failed with error: {e}')
        try:
            self.logger.info(
                f'Attempting to create views with {self.view_creator}')
            cmd = [self.view_creator]
            res = check_output(cmd)
            self.logger.info(f'Results from self.view_creator: {res}')
        except Exception as e:
            traceback.print_stack()
            self.logger.error(f'Problem creating views: {e}')
            raise SlurpException(f'Slurper error: {e}')
