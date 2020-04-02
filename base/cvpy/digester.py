#!/usr/bin/env python3
"""Contains the Digest() class which will take the assimilated CSVs."""
import logging
from cvpy.database import Database
from cvpy.common import check_environment as ce


class Digest():
    """Clean up output CSV from Ingest and import into the database.

    The Digest class takes the single CSV output from the Ingest() class and
    inserts it into the database.
    """

    def __init__(self, aggregate_csv, production=ce('PRODUCTION', 'False'),
                 logger=logging.getLogger(ce('PY_LOGGER', 'main'))):
        self.aggregate = aggregate_csv
        if production == 'False':
            self.production =  False
        elif production == 'True':
            self.production = True
        self.logger = logger



