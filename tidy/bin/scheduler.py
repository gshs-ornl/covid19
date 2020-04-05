#!/usr/bin/env python3
"""Monitors $INPUT_DIR for any file changes."""
import time
import logging
import traceback
from cvpy.logging import DictLogger
from cvpy.common import check_environment as ce
from cvpy.watch import DataHandler, SlurpHandler
from watchdog.observers import Observer

logging.config.dictConfig(DictLogger.SIMPLE)
logger = logging.getLogger(ce('PY_LOGGER', 'main'))

if __name__ == "__main__":
    input_dir = ce('INPUT_DIR', '/tmp/input')
    clean_dir = ce('CLEAN_DIR', '/tmp/clean')
    clean_observer = Observer()
    slurp_observer = Observer()
    clean_observer.schedule(DataHandler, input_dir, recursive=True)
    slurp_observer.schedule(SlurpHandler, clean_dir, recursive=True)
    clean_observer.start()
    slurp_observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        traceback.print_stack()
        logger.critical('COVID19 Digesters stopped by user kill signal.')
        clean_observer.stop()
        slurp_observer.stop()
    clean_observer.join()
    slurp_observer.join()
