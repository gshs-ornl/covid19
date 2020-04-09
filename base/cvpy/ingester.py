#!/usr/bin/env python3
"""The ingester imports all csvs in the output directory."""
import os
import glob
import logging
import traceback
import pandas as pd
from datetime import datetime
from cvpy.common import check_environment as ce
from cvpy.exceptions import IngestException
from cvpy.common import glob_csvs


class Ingest():
    """Ingests all csvs in the output directory, and writes aggregate to the
       $INPUT_DIR."""
    def __init__(self, csv = None,
                 production=ce('PRODUCTION', default='False'),
                 logger=logging.getLogger(ce('PY_LOGGER', 'main'))):
        """Set up the Ingest class for ingestion of csvs."""
        self.df_list = []
        self.csv_list = []
        self.logger = logger
        self.output_data = None
        self.output_file = None
        self.output_dir = ce('OUTPUT_DIR', '/tmp/output')
        self.input_dir = ce('INPUT_DIR', '/tmp/input')
        self.logger.info(f'Input directory set as {self.output_dir}')
        self.num_csvs = len(self.csv_list)
        self.logger.info(f'Found {len(self.csv_list)} csvs to ingest')
        if production.lower() == 'true':
            self.production = True
        elif production.lower() == 'false':
            self.production = False
        else:
            raise IngestException(
                f'Unrecognized production value {production}')
        self.csv = csv
        if production:
            if self.csv is None:
                self.populate_csv_list()
                self.make_output_filename()
                self.aggregate_csvs()
                self.combine_dfs()
                self.make_output_file()
            else:
                self.output_data = pd.read_csv(self.csv)
                self.make_output_file()

        else:
            self.logger.info(
                'Not running in production, methods must be called manually.')

    def populate_csv_list(self):
        """Populate the list csv_list element."""
        if os.path.exists(self.output_dir):
            self.csv_list = glob_csvs(self.output_dir, self.logger)
        else:
            msg = 'Output directory {self.output_dir} does not exist!'
            self.logger.error(msg)
            raise IngestException(msg)
        if self.csv_list == []:
            msg = 'No CSVs found in {self.output_dir}'
            self.logger.error(msg)
            raise IngestException(msg)

    def make_output_filename(self, increment=False):
        """Create the file that will arrive in the $INPUT directory."""
        self.increment_amount = 0
        if increment:
            fn = 'agg_' + datetime.utcnow().strftime('%Y-%m-%d-%H%M') + \
                '_.csv'
        else:
            fn = 'agg_' + datetime.utcnow().strftime('%Y-%m-%d-%H%M') + '.csv'
        self.output_file = os.path.join(self.input_dir, fn)
        # catch error in case more than one file exists
        if os.path.exists(self.output_file):
            self.logger.warning(
                f'Output file {self.output_file} already exists! Incrementing')
            self.increment_amount += 1
            self.make_output_filename(increment=True)

    def aggregate_csvs(self):
        """Aggregate the csvs in self.csv_list."""
        if self.df_list != []:
            for f in self.csv_list:
                try:
                    self.df_list.append(pd.read_csv(f))
                    os.remove(f)
                    self.csv_list.remove(f)
                except pd.errors.EmptyDataError as e:
                    traceback.print_stack()
                    self.logger.warning(
                        f'Pandas encountered an error: {e}\n' +
                        f'Empty file {f}. Removing from list.')
                    os.remove(f)
                    self.csv_list.remove(f)
                    self.num_csvs -= 1
                except pd.errors.ParserError as e:
                    traceback.print_stack()
                    self.logger.error(
                        f'Pandas encountered an error {e} while ' +
                        f'processing {f}. Skipping.')
                    self.csv_list.remove(f)
                    self.num_csvs -= 1
                except FileNotFoundError as e:
                    traceback.print_stack()
                    self.logger.error(
                        f'{e}: File {f} was not found. Removing from list.')
                    self.csv_list.remove(f)
                    self.num_csvs -= 1
        else:
            self.logger.warning(
                'DF List is already populated. Issues may arise.')
        if len(self.df_list) != self.num_csvs:
            self.logger.error(
                f'CSV list {self.num_csvs} does not equal ' +
                f'DF list {len(self.df_list)}. ' +
                'Some CSVs were not removed.')

    def combine_dfs(self):
        """Combine all the DataFrames in self.df_list."""
        try:
            self.output_data = pd.concat(self.df_list, axis=0,
                                         ignore_index=True)
        except Exception as e:
            traceback.print_stack()
            self.logger.error('Problem concatenating DataFrames: {e}')
            raise IngestException(e)

    def make_output_file(self):
        """Write the concatenated DataFrame to the output file."""
        try:
            self.output_data.to_csv(self.output_file)
        except Exception as e:
            traceback.print_stack()
            msg = f'Encountered error {e} while writing to {self.output_file}.'
            self.logger.error(msg)
            raise IngestException(msg)
