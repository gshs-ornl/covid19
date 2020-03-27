#!/usr/bin/env python3
"""
    This class is responsible for interacting with the covidb database
"""
import os
import re
import sys
import logging
import psycopg2
import traceback
import pandas as pd
from cvpy.common import check_environment as ce


class Database(object):
    """ provides a convenient API-like interface to the covidb database

        :param db_name the name of the database to connect to
    """
    def __init__(logger=logging.getLogger('main'),
                 email_list=['grantjn@ornl.gov', 'piburnjo@ornl.gov',
                             'kaufmanjc@ornl.gov']):
        self.timeout = int(ce('DB_TIMEOUT', '60'))
        self.user = ce('DB_USER', 'guest')
        self.passwd = ce('DB_PASS', 'abc123')
        self.host = ce('DB_HOST', 'localhost')
        self.database = ce('DB_DATABASE', 'covidb')
        DB_PORT = int(ce('DB_PORT', '5432'))




