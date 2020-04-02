#!/usr/bin/env python3
"""Runs all the scripts in the SCRIPT_DIR (/tmp/scripts by default)."""
import logging
from datetime import datetime
from cvpy.logging import DictLogger
from cvpy.common import get_all_scripts
from cvpy.runners import run_script
from cvpy.common import check_environment as ce
# retrieve the logger
PY_LOGGER = ce('PY_LOGGER', 'main')
logging.config.dictConfig(DictLogger.SIMPLE)
logger = logging.getLogger(PY_LOGGER)


if __name__ == "__main__":
    run_start = datetime.utcnow()
    logger.info(f'Starting scrape at {run_start}')
    script_dir = ce('SCRIPT_DIR', './scripts')
    scripts = get_all_scripts(script_dir)
    logger.info(f'Found {len(scripts)} to run')
    results = []
    for script in scripts:
        logger.info(f'Running script {script}')
        if script.endswith('.py'):
            results.append(run_script(script, 'py'))
        elif script.endswith('.R'):
            results.append(run_script(script, 'r'))
    # TODO add an elegant way to handle the results, probably a cvpy method
    print(results)
