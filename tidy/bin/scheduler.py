#!/usr/bin/env python3
"""Monitors $INPUT_DIR for any file changes."""
import time
import logging
import traceback
from cvpy.logging import DictLogger
from cvpy.common import check_environment as ce
from cvpy.watch import DataHandler, SlurpHandler, ScrapeHandler
from watchdog.observers import Observer

logging.config.dictConfig(DictLogger.SIMPLE)
logger = logging.getLogger(ce('PY_LOGGER', 'main'))

if __name__ == "__main__":
    input_dir = ce('INPUT_DIR', '/tmp/input')
    output_dir = ce('OUTPUT_DIR', '/tmp/output')
    clean_dir = ce('CLEAN_DIR', '/tmp/clean')
    logger.info('Creating the input_observer')
    input_observer = Observer()
    logger.info('Creating the clean_observer')
    clean_observer = Observer()
    logger.info('Creating the slurp_observer')
    slurp_observer = Observer()
    input_observer.schedule(ScrapeHandler, input_dir, recursive=True)
    clean_observer.schedule(DataHandler, output_dir, recursive=True)
    slurp_observer.schedule(SlurpHandler, clean_dir, recursive=True)
    input_observer.start()
    clean_observer.start()
    slurp_observer.start()
    try:
        logger.info('Beginning infinite loop.')
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        traceback.print_stack()
        logger.critical('COVID19 Digesters stopped by user kill signal.')
        input_observer.stop()
        clean_observer.stop()
        slurp_observer.stop()
    input_observer.join()
    clean_observer.join()
    slurp_observer.join()
