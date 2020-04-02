#!/usr/bin/env python3
"""Contains runners for scraping, tidying, etc."""
from cvpy.errors import ScriptError
from tempfile import TemporaryFile
from subprocess import check_output, CalledProcessError


def run_script(script, script_type):
    """Run a script, capture the output and exit code."""
    with TemporaryFile() as t:
        try:
            if script_type == 'py':
                out = check_output(['python3', script], stderr=t, stdout=t)
            if script_type == 'R':
                out = check_output(['Rscript', script], stderr=t, stout=t)
            return 0, out
        except CalledProcessError as e:
            t.seek(0)
            msg = f"{script} failed with exit code {e.returncode} " + \
                f"and message {t.read()}"
            ScriptError(script, msg).email()
            return e.returncode, t.read()
