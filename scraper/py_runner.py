#!/usr/bin/env python3
"""Runs all the scripts in the SCRIPT_DIR (/tmp/scripts by default)."""
import cvpy
import logging
from glob import glob
from datetime import datetime
from cvpy.error import ScriptError
from tempfile import TemporaryFile
from cvpy.common import check_environment as ce
from subprocess import check_output, CalledProcessError


def get_all_scripts(script_dir):
    """Retrieve all scripts in the specified directory."""
    r_scripts = glob(f'{script_dir}/*.R')
    py_scripts = glob(f'{script_dir}/*.py')
    return r_scripts + py_scripts


def run_script(script):
    """Run a script, capture the output and exit code."""
    with TemporaryFile() as t:
        try:
            out = check_output([script], stderr=t, stdout=t)
            return 0, out
        except CalledProcessError as e:
            t.seek(0)
            msg = f"{script} failed with exit code {e.returncode} " + \
                f"and message {t.read()}"
            ScriptError(script, msg).email()
            return e.returncode, t.read()


if __name__ == "__main__":
    run_start = datetime.utcnow()
    scripts = get_all_scripts(ce('SCRIPT_DIR', '/tmp/scripts'))
    for script in scripts:
        logging.info(f'Running script {script}')
        run_script(script)
