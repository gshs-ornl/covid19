#!/usr/bin/env python3
# -*- coding: utf-8 -*-
""" this file contains static dataclasses for use in cron_scheduler """
import os
from dataclasses import dataclass
from pathlib import Path
from pathlib import PosixPath
from enum import Enum, unique
from cvr.common import check_environment as ce
from ei.ResolutionType import ResolutionType


@dataclass
class Directories:
    """ provides a dataclass of hardcoded directories

        Args:
            TIMINGS: (PosixPath) directory to store timings
            OUTAGES: (PosixPath) directory to store outages
            ERRORS: (PosixPath) directory to store errors
            OUTPUT: (PosixPath) directory to store output

    """
    OUTPUT: PosixPath = Path('/tmp/output/')
    LOGS: PosixPath = Path('/tmp/logs/')

@dataclass
class DatabaseConnectionInfo:
    """ provides the default database connection information """
    TIMEOUT: int = 60
    DB = 'eaglei_db'
    USER = 'eiadmin'
    PW = '34gl31yo'
    HOST = 'db'
    PORT = 5006
    SCHEMA = 'outage_data'
    MAX_ATTEMPTS = 3
    SECS_TO_WAIT = 10
    DEFAULT_SCHEMA = 'outage_data'


class PollingInfo:
    """ provides default values related to polling """
    INTERVAL = 15
    SLEEP = 10
    MINUTE = 15
    WEB_TIMEOUT = 600


class Colors:
    """ provides a dataclass of colors for pretty printing """
    BLACK = '\33[30m'
    RED = '\33[31m'
    GREEN = '\33[32m'
    YELLOW = '\33[33m'
    BLUE = '\33[34m'
    VIOLET = '\33[35m'
    BEIGE = '\33[36m'
    WHITE = '\33[37m'
    RESET = '\33[39m'


class Files:
    """ define the default file paths in the container """
    CACHE = Path('/tmp/output/cache.db')
    CACHE_STR = '/tmp/output/cache.db'
    TIMINGS = Path('/tmp/output/timings/sched_timings.csv')
    TIMINGS_STR = '/tmp/output/timings/sched_timings.csv'
    LOG = Path('/tmp/logs/ei_sched.log')
    LOG_STR = '/tmp/logs/ei_sched.log'
    ETL_LOG = Path('/tmp/logs/etl.log')
    ETL_LOG_STR = '/tmp/logs/etl.log'
    ROTATE_LOG = Path('/tmp/logs/ei_etl.log')
    ROTATE_LOG_STR = '/tmp/logs/ei_etl.log'
    LOG_FILE = Path('/tmp/logs/ei.log')
    LOG_FILE_STR = '/tmp/logs/ei.log'


class ParserArgs():
    def __init__(self, verbose=None, once=False, interval=None, sleep=None,
                 timeout=None, workers=None, logfile=None):
        assert isinstance(once, bool)
        if verbose is None:
            self.verbose = True
        else:
            self.verbose = verbose
        self.once = once
        if interval is None:
            self.interval = int(ce('POLLING_INTERVAL', 15))
        else:
            self.interval = interval
        if sleep is None:
            self.sleep = int(ce('SLEEP_INTERVAL', 4))
        if workers is None:
            self.workers = int(os.cpu_count())
        else:
            self.workers = workers
        if timeout is None:
            self.timeout = 600
        else:
            self.timeout = timeout


class DefaultArgs:
    sleep = 4
    timeout = PollingInfo.WEB_TIMEOUT
    workers = os.cpu_count()
    once = False


class _db_methods:
    """ provides db methods and retrieves operational instructions """
    # TODO include the invocation methods for the following
    SQLITE = {'method': 'sqlite', 'invocation': '<TODO>'}
    POSTGRES = {'method': 'postgres', 'invocation': '<TODO>'}


class LoggingInfo:
    MASTERFORMAT = f'[{Colors.YELLOW}%(asctime)s{Colors.RESET}]' + \
        f'-({Colors.BEIGE}%(process)d{Colors.RESET})- ' + \
        f'{Colors.GREEN}%(levelname)8s{Colors.RESET} - ' + \
        f'-({Colors.BEIGE}%(process)d)- ' + \
        f'{Colors.GREEN}%(levelname)4s{Colors.RESET} - ' + \
        f'{Colors.BEIGE}%(module)8s' + \
        f'{Colors.RESET}:{Colors.VIOLET}%(funcName)s' +\
        f'{Colors.RESET}:{Colors.YELLOW}%(lineno)d{Colors.RESET}]' + \
        ' - %(message)s'
    FORMAT = f'[{Colors.YELLOW}%(asctime)s{Colors.RESET}]' + \
        f'{Colors.GREEN}%(levelname)8s{Colors.RESET} - ' + \
        f'{Colors.BEIGE}%(module)8s' + \
        f'{Colors.RESET}:{Colors.VIOLET}%(funcName)s' +\
        f'{Colors.RESET}:{Colors.YELLOW}%(lineno)d{Colors.RESET}]' + \
        ' - %(message)s'
    DATEFMT = "%Y/%m/%d %H:%M:%S"
    SERVER = 'localhost'
    SERVER_PORT = '9999'
    SHORT_FORMAT = f'[{Colors.BEIGE}%(asctime)s{Colors.RESET}]' + \
        f'{Colors.YELLOW}%(levelname)4s{Colors.RESET} - ' + \
        f'{Colors.BEIGE}%(module)8s{Colors.RESET}::' + \
        f'{Colors.VIOLET}%(lineno)d{Colors.RESET} - ' + \
        f'%(message)s'
    SERVER_CLASS: str = 'ei.logging.ServerLogging'
    MULTIPROCESS: str = 'ei.logging.MultiprocessLogging'
    MASTER_FILE: str = '/tmp/ei_etl_master.log'
    ROTATE_FORMAT = '[%(asctime)s]-[%(levelname)s%(name)s]' + \
        '{%(process)d}:%(filename)s|%(funcName)s:%(lineno)s - %(message)s'
