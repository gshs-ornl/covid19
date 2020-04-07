#!/usr/bin/env python3
"""Contains the Digest() class which will take the assimilated CSVs."""
import os
import logging
import traceback
from cvpy.static import DbData
from cvpy.common import check_environment as ce
from cvpy.common import get_csv, glob_csvs
from cvpy.exceptions import DigestException


class Digest():
    """Clean up output CSV from Ingest and import into the database.

    The Digest class takes the single CSV output from the Ingest() class and
    inserts it into the database.
    """

    def __init__(self, csv=None, production=ce('PRODUCTION', 'False'),
                 logger=logging.getLogger(ce('PY_LOGGER', 'main')),
                 run=False, output_dir=ce("INPUT_DIR", "/tmp/input"),
                 clean_dir=ce("CLEAN_DIR", '/tmp/clean')):
        self.logger = logger
        self.run = run
        self.csv = None
        if production == 'False':
            self.production = False
        elif production == 'True':
            self.production = True
            self.run = True
        else:
            self.logger.warning(f'Unknown PRODUCTION content: {production}. ' +
                                'Defaulting to False')
            self.production = False
        self.output_dir = output_dir
        self.clean_dir = clean_dir
        if self.run:
            if self.csv is None:
                self.csv_list = glob_csvs(self.output_dir, self.logger)
                for c in self.csv_list:
                    process_successful = self.process(c)
                    if process_successful:
                        self.remove(c)
                    else:
                        # raise DigestException(
                        # f'Error processing {self.aggregate}')
                        self.logger.error(
                            f'Error processing {c}. . . skipping.')
            else:
                self.csv = csv
                success = self.process(self.csv)
                if success:
                    self.remove(self.csv)
                    self.csv = None
                else:
                    self.logger.error(
                        f'Error processing {self.csv} . . . skipping')

    def __str__(self):
        """Print the object."""
        if self.csv:
            return f"Digesting {self.csv} with PRODUCTION = " + \
                f"{self.production}\n" + \
                f"\tInput Directory:\t{self.ouput_dir}\n\tOutput Directory" + \
                f":/t{self.clean_dir}"
        return f"Digesting {len(self.csv_list)} with PRODUCTION = " + \
            f"{self.production}\n" + \
            f"{\tInput Directory:\t{self.output_dir}\n\tOutputDirectory:\t" + \

    def remove(self, csv_file):
        """Remove the aggregate file."""
        try:
            os.remove(csv_file)
        except OSError as e:
            self.logger.error(
                f'Problem removing aggregate {csv_file}: {e}')

    def process(self, csv_file):
        """Process the aggregate into a file and write to the output dir."""
        # TODO add better exception handling here
        dat = get_csv(csv_file, self.logger)
        dat.astype(DbData.RAW)
        filepath, fn = os.path.split(self.aggregate)
        if filepath != self.output_dir:
            traceback.print_stack()
            logging.error(f'Aggregate base path {filepath} does not match ' +
                          f'{self.output_dir}. Unknown forward process.' +
                          'Passing . . . . .')
            return False
        fn_out = 'cleaned_' + fn
        fileout = os.path.join(self.clean_dir, fn_out)
        try:
            dat.to_csv(fileout)
        except Exception as e:
            raise DigestException(f'Digestion error {e} occurred.')
            return False
        return True
