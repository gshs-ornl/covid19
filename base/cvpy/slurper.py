#!/usr/bin/env python3
"""Contains methods for slurping data from the $INPUT_DIR into the database."""
import os
import logging
import traceback
from cvpy.database import Database
from cvpy.common import check_environment as ce
from cvpy.errors import SlurpError


class Slurp():
    """Slurps an $CLEAN_DIR CSV into the database and creates views."""

    def __init__(self, csv_file, clean_dir=ce('CLEAN_DIR', '/tmp/clean'),
                 logger=logging.getLogger(ce('PY_LOGGER', 'main')),
                 view_creator=ce('VIEW_CREATOR', 'create_views.sql')):
        """Initialize the Slurp."""
        if os.path.exists(self.csv):
            self.csv = csv_file
        else:
            self.csv = os.path.join(clean_dir, csv_file)
        self.logger = logger
        self.view_creator = view_creator

    def process(self):
        """Process the CSV passed during Slurp initialization."""
        # TODO fill in with better logic
        self.logger.info(f'Proceeding with file {self.csv}')
        try:
            with Database() as db:
                db.import_raw(self.csv)
            os.remove(self.csv)
            self.csv = None
        # TODO better exception handling
        except OSError as e:
            traceback.print_stack()
            self.logger.error(f'File removal issue for {self.csv}: {e}')
        except Exception as e:
            traceback.print_stack()
            self.logger.error(f'Problem slurping {self.csv}: {e}')
            raise SlurpError(f'Slurper: {self.csv}',
                             'Slurping of CSV failed with error: {e}')
