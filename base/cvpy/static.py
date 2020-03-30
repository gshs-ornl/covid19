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
    ROTATE_LOG = Path('/tmp/cvpy_rotate.log')
    ROTATE_LOG_STR = '/tmp/cvpy_rotate.log'



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


class Headers:
    site = ['country', 'state', 'url', 'page', 'access_time',
            'county', 'cases', 'updated', 'deaths', 'presumptive',
            'recovered', 'tested', 'hospitalized', 'negative',
            'counties', 'severe', 'lat', 'lon', 'fips', 'monitored',
            'no_longer_monitored', 'pending', 'active', 'inconclusive',
            'quarantined', 'private_tests', 'state_tests',
            'scrape_group', 'resolution', 'icu',
            'cases_0_9', 'cases_10_19', 'cases_20_29', 'cases_30_39',
            'cases_40_49', 'cases_50_59', 'cases_60_69',
            'cases_70_79', 'cases_80', 'hospitalized_0_9',
            'hospitalized_10_19', 'hospitalized_20_29',
            'hospitalized_30_39', 'hospitalized_40_49',
            'hospitalized_50_59', 'hospitalized_60_69',
            'hospitalized_70_79', 'hospitalized_80', 'deaths_0_9',
            'deaths_10_19', 'deaths_20_29', 'deaths_30_39',
            'deaths_40_49', 'deaths_50_59', 'deaths_60_69',
            'deaths_70_79', 'deaths_80', 'cases_male', 'cases_female']
    tomq = ['County_Name', 'State_Name', 'Confirmed', 'New Death',
            'Fatality_Rate', 'Last_Update', ' Latitude', 'Longitude',
            'New_Death']
    nyt_county = ['date', 'county', 'state', 'fips', 'cases', 'deaths']
    nyt_state = ['date', 'state', 'fips', 'cases', 'deaths']
    hopkins = ['state', 'country_region', 'updated cases', 'deaths',
               'recovered', 'state', 'lat', 'lon', 'fips', 'admin2',
               'provice_state', 'country', 'last_updated', 'latitude',
               'longitude', 'active', 'combined_keys', 'fips']
    hattiesburg = ['country', 'cases', 'deaths', 'recovered', 'active',
                   'unknown', 'update_time', 'something', 'lat', 'lon', 'date']


