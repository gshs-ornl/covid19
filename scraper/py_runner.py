#!/usr/bin/env python3
"""Runs all the scripts in the SCRIPT_DIR (/tmp/scripts by default)."""
import logging
from datetime import datetime
from cvpy.common import check_environment as ce
from cvpy.logging import DictLogger
from cvpy.common import get_all_scripts
from cvpy.runners import run_script
# retrieve the logger
PY_LOGGER = ce('PY_LOGGER', 'main')
logging.dictConfig(DictLogger.SIMPLE)
logger = logging.getLogger(PY_LOGGER)


if __name__ == "__main__":
    run_start = datetime.utcnow()
    logger.info(f'Starting scrape at {run_start}')
    scripts = get_all_scripts(ce('SCRIPT_DIR', '/tmp/scripts'))
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
