#!/usr/bin/env python3
"""Provides module specific exceptions."""
import sys
import logging
import traceback
from cvpy.common import check_environment as ce
from cvpy.errors import ErrorType

class BaseException(Exception):
    """Provides base exception class for all exceptions."""
    def __init__(self, text, err_type=ErrorType.Unknown,
                 logger=logging.getLogger(ce('PY_LOGGER', 'main')))
        super().__init__(text, err_type)
        print("-" * 60)
        traceback.print_stack()
        print("-" * 60)

    def text(self):
        return self.args[0]

    def type(self):
        return self.args[1]


class DigestException(BaseException):
    """An error during digestion occurred."""
    def __init__(self, text):
        super().__init__(text, ErrorType.Digest)
