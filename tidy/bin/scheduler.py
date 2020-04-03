#!/usr/bin/env python3
"""Monitors $INPUT_DIR for any file changes."""
import sys
import time
import logging
from cvpy.logging import DictLogger
from cvpy.common import check_environment as ce
from cvpy.errors import SlurpError
from watchdog.observers import Observer
from watchdog,events import LoggingEventHandler

logging.config.dictConfig(DictLogger.SIMPLE)
logger = logging.getLogger(ce('PY_LOGGER', 'main'))

if __name__ == "__main__":
    input_dir = ce('INPUT_DIR', '/tmp/input')
    event_handler = LoggingEventHandler()
    observer = Observer()
