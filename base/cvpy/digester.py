#!/usr/bin/env python3
"""Contains the Digest() class which will take the assimilated CSVs."""
import os
import logging
import traceback
from cvpy.static import DbData
from cvpy.common import check_environment as ce
from cvpy.common import get_csv
from cvpy.exceptions import DigestException


class Digest():
    """Clean up output CSV from Ingest and import into the database.

    The Digest class takes the single CSV output from the Ingest() class and
    inserts it into the database.
    """

    def __init__(self, aggregate_csv, production=ce('PRODUCTION', 'False'),
                 logger=logging.getLogger(ce('PY_LOGGER', 'main')),
                 run=False, output_dir=ce("OUTPUT_DIR", "/tmp/output"),
                 clean_dir=ce("CLEAN_DIR", '/tmp/clean')):
        self.logger = logger
        self.aggregate = aggregate_csv
        if production == 'False':
            self.production = False
        elif production == 'True':
            self.production = True
        else:
            self.logger.warning(f'Unknown PRODUCTION content: {production}. ' +
                                'Defaulting to False')
            self.production = False
        self.output_dir = output_dir
        self.clean_dir = clean_dir
        if run:
            self.read()
            process_successful = self.process()
            if process_successful:
                self.remove()
            else:
                raise DigestException(f'Error processing {self.aggregate}')

    def __str__(self):
        """Print the object."""
        return f"Digesting {self.aggregate} with PRODUCTION = " + \
            f"{self.production}\n" + \
            f"\tInput Directory:\t{self.ouput_dir}\n\tOutput Directory:\t" + \
            f"{self.clean_dir}"

    def remove(self):
        """Remove the aggregate file."""
        try:
            os.remove(self.aggregate)
        except OSError as e:
            self.logger.error(
                f'Problem removing aggregate {self.aggregate}: {e}')

    def read(self):
        """Read the aggregate into pandas."""
        self.dat = get_csv(self.aggregate, logger=self.logger)

    def process(self):
        """Process the aggregate into a file and write to the output dir."""
        # TODO add better exception handling here
        self.dat.astype(DbData.RAW)
        filepath, fn = os.path.split(self.aggregate)
        if filepath != self.output_dir:
            traceback.print_stack()
            logging.error(f'Aggregate base path {filepath} does not match ' +
                          f'{self.output_dir}. Unknown forward process.' +
                          'Passing . . . . .')
            return False
        fn_out = 'cleaned_' + fn
        fileout = os.path.join(self.output_dir, fn_out)
        try:
            self.dat.to_csv(fileout)
        except Exception as e:
            raise DigestException(f'Digestion error {e} occurred.')
            return False
        return True
