#!/usr/bin/env python3
"""Test that cvpy modules can be loaded."""
# import test helpers
import cvpy
import logging
import unittest

# create the logger
logger = logging.getLogger('main')
global logger

logger.info('cvpy successfully loaded and logging setup.')

# import common
class FunctionsTestCase(unittest.TestCase):
    def setUp(self):
        self.functions = [['check_environment', 'get_all_scripts',
                          'create_uri', 'glob_csvs'],
                          ['send_email']
                          ]
        self.modules = ['common', 'emails']

    def testCommonLoad(self):
        i = 0
        for m in self.modules:
            for f in self.functions[i]:
                mycode = f'import cvpy.{self.module}.{f}'
                logger.info(f'Executing "{mycode}"')
                exec(mycode)
                logger.info(f'Function {f} successfully loaded')
                i += 1


class ClassesTestCase(unittest.TestCase):
    def setup(self):
        self.classes = [['Database'], ['Digest'],
                        ['ScriptError', 'SlurpError', 'ErrorType']
                        ['BaseException', 'DigestException',
                         'SlurpException', 'ScriptException',
                         'IngestException', 'GlobException',
                         'DatabaseException', 'ReadImageException',
                         'ReadPDFException'], ['Ingest']]
        self.modules = ['database', 'digester', 'errors',
                        'exceptions', 'ingester']

    def testClassload(self):
        i = 0
        for m in self.modules:
            for c in self.classes[i]:
                mycode = f'from cvpy.{m} import {c}'
                logger.info(f'executing "{mycode}"')
                exec(mycode)
                logger.info(f'Class {c} from module {m} successfully loaded')
                i += 1


        mycode = f'from cvpy.{self.module} import {self.classes}'
        logger.info(f'executing {mycode}')
        exec(mycode)
        logger.info(f'database class successfully loaded')

import cvpy.digester
import cvpy.emails
import cvpy.errors
import cvpy.exceptions
import cvpy.ingester
import cvpy.logging
