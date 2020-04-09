#!/usr/bin/env python3
"""Provides module specific exceptions."""
import logging
import traceback
from cvpy.common import check_environment as ce
from cvpy.errors import ErrorType


class BaseException(Exception):
    """Provides base exception class for all exceptions."""
    def __init__(self, text, err_type=ErrorType.Unknown,
                 logger=logging.getLogger(ce('PY_LOGGER', 'main'))):
        """Initialize the BaseException class."""
        super().__init__(text, err_type)
        print("-" * 60)
        traceback.print_stack()
        print("-" * 60)

    def text(self):
        """Return the text of the exception."""
        return self.args[0]

    def type(self):
        """Return the type of the exception."""
        return self.args[1]


class DigestException(BaseException):
    """An error during digestion occurred."""
    def __init__(self, text):
        """Initialize the DigestException."""
        super().__init__(text, ErrorType.Digest)


class SlurpException(BaseException):
    """An error occurred during slurping."""
    def __init__(self, text):
        """Initialize the SlurpException."""
        super().__init__(text, ErrorType.Slurp)


class ScriptException(BaseException):
    """An error occurred during script execution."""
    def __init__(self, text):
        """Initialize the script exception."""
        super().__init__(text, ErrorType.Script)


class IngestException(BaseException):
    """An error occurred during ingestion."""
    def __init__(self, text):
        """Initialize the ingest exception."""
        super().__init__(text, ErrorType.Ingest)


class GlobException(BaseException):
    """An error occurred while globbing for CSVs."""
    def __init__(self, text):
        """Initialize the glob exception."""
        super().__init__(text, ErrorType.Glob)


class DatabaseException(BaseException):
    """An error occurred while using the database."""
    def __init__(self, text):
        """Initialize the database exception."""
        super().__init__(text, ErrorType.Database)
