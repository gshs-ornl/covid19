#!/usr/bin/env python3
"""The Database class is responsible for interacting with the covidb database.\
"""
import logging
import psycopg2
import traceback
import pandas as pd
from sqlalchemy import create_engine
from cvpy.common import check_environment as ce
from cvpy.common import create_uri
from cvpy.exceptions import DatabaseException
import dsnparse

class Database(object):
    """Provides a convenient API-like interface to the covidb database.
    The database object is the interface to the covidb database.
        :param db_name the name of the database to connect to
    """
    def __init__(self, logger=logging.getLogger(ce('PY_LOGGER', 'main')), dsn=None,
                 email_list=['grantjn@ornl.gov', 'piburnjo@ornl.gov',
                             'kaufmanjc@ornl.gov']):
        """Initiate the database object."""
        self.timeout = int(ce('DB_TIMEOUT', '60'))
        if dsn:
            dp = dsnparse.parse(dsn)
            self.user = dp.username
            self.passwd = dp.password
            self.host = dp.host
            self.database = dp.paths[0]
            self.port = int(dp.port)
        else:
            self.user = ce('DB_USER', 'guest')
            self.passwd = ce('DB_PASS', 'abc123')
            self.host = ce('DB_HOST', 'localhost')
            self.database = ce('DB_DATABASE', 'covidb')
            self.port = int(ce('DB_PORT', '5432'))
        self.con = None
        self.cur = None
        self.uri = None
        self.logger = logger
        self.recipients = email_list
        self.logger.debug('Initiated Database Object')

    def __del__(self):
        """Delete default del for object."""
        self.logger.debug('Removing Database Object')
        self.close()

    def __enter__(self):
        """Use with to enter database object."""
        self.logger.debug('Entering Database Object')
        self.open()
        return self

    def __exit__(self, err_type, err_value, err_traceback):
        """Exit gracefully."""
        self.logger.debug('Exiting Database Object')
        self.close()

    def open(self):
        """Open the connection to the database."""
        self.logger.debug('Opening Database Object')
        try:
            msg = '\nConnecting information\n' + \
                f'Database: {self.database}\n' + \
                f'Host: {self.host}\n' + f'Port: {self.port}\n' + \
                f'User: {self.user}\n'
            self.logger.debug(msg)
            self.con = psycopg2.connect(
                database=self.database,
                user=self.user,
                password=self.passwd,
                host=self.host,
                port=self.port,
                connect_timeout=self.timeout)
            self.logger.debug('Successfully opened database connection')
            self.cur = self.con.cursor()
            self.logger.debug('Successfully created database cursor')
            self.cur.execute("SET search_path TO covidb;")
        except psycopg2.OperationalError as e:
            self.logger.error(f'Database error: {e}')

    def close(self):
        """Close the database connection."""
        self.logger.debug('Closing the database coinnection')
        if hasattr(self, 'cur') and self.cur is not None:
            self.logger.debug('Closing cursor and setting to None')
            self.cur.close()
            self.cur = None
        if hasattr(self, 'con') and self.con is not None:
            self.logger.debug('Closing connection and setting to None')
            self.con.commit()
            self.con.close()
            self.con = None
        if hasattr(self, 'engine') and self.engine is not None:
            self.logger.debug('Closig sqlalchemy connection')
            self.engine.dispose()
        self.logger.debug('Database object successfully closed.')

    def query(self, query):
        """Send a query to the database and retrieve the results."""
        self.logger.debug(f'Initiating query: {query}')
        try:
            self.cur.execute(query)
            res = self.cur.fetchall()
        except Exception as e:
            traceback.print_stack()
            self.logger.error(f'Problem querying database: {e}')
            res = None
        return res

    def fetch_county_data(self, scrape_group=None):
        """Fetch county data."""
        if scrape_group is None:
            query = "SELECT * FROM scraping.vw_county_data;"
            res = self.query(query)
        else:
            query = f"""SELECT * FROM scraping.vs_county_data
                        WHERE scrape_group = {scrape_group};"""
            res = self.query(query)
        return res

    def fetch_state_data(self, scrape_group=None):
        """Fetch the state data."""
        if scrape_group is None:
            query = "SELECT * FROM scraping.vw_state_data;"
            res = self.query(query)
        else:
            query = f"""SELECT * FROM scraping.vw_state_data
                        WHERE scrape_group = {scrape_group};"""
            res = self.query(query)
        return res

    def insert_raw_data(self, df, uri=None):
        """Insert raw data into database."""
        if not isinstance(df, pd.DataFrame):
            msg = f'Object passed was of type {type(df)}, not a ' + \
                'Pandas DataFrame'
            self.logger.error(msg)
            raise DatabaseException(msg)
        if uri is None:
            self.logger.warning('URI was not passed, please pass explicitly.')
            uri = create_uri(self.logger)
        if not hasattr(self, 'engine'):
            self.engine = create_engine(uri)
        df.to_sql('raw_data', self.engine, schema='scraping',
                  if_exists='append', index=False, method='multi')
