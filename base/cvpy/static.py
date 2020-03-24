#!/usr/bin/env python3
# -*- coding: utf-8 -*-
""" this file contains static information """
import os
from pathlib import Path
from pathlib import PosixPath
from enum import Enum, unique
from cvpy.common import check_environment as ce


class Directories:
    """ provides a dataclass of hardcoded directories

        Args:
            OUTPUT: (PosixPath) directory to store output
            LOGS: (PosixPath) directory to store logs

    """
    OUTPUT = Path('/tmp/output/')
    LOGS = Path('/tmp/logs/')


class DatabaseConnectionInfo:
    """ provides the default database connection information """
    TIMEOUT = 60
    DB = 'covidb'
    USER = os.getenv('DB_USER')
    PW = os.getenv('DB_PASS')
    HOST = 'covidb'
    PORT = 5006
    SCHEMA = 'scraping'
    MAX_ATTEMPTS = 3
    SECS_TO_WAIT = 10
    DEFAULT_SCHEMA = 'scraping'


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

    LOG = Path('/tmp/cvpy.log')
    LOG_STR = '/tmp/cvpy.log'


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
    ROTATE_FORMAT = '[%(asctime)s]-[%(levelname)s%(name)s]' + \
        '{%(process)d}:%(filename)s|%(funcName)s:%(lineno)s - %(message)s'
