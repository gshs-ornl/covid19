#!/usr/bin/env python3
"""Contains common functions used throughout the cvpy package."""
import os
import logging
from glob import glob


def check_environment(env_var, default=None):
    """Check for environmental variables in all scopes.

        Check if an environmental variable or variable is set, and if so,
        return that value, else return the default variable

        :param env_var the environmental variable to look for
        :param default the default value if the environmental variable is not
                       found
        :return returns either the value in the environmental variable or the
                        default value passed to this function (default of None)
    """
    if env_var in os.environ:
        return os.environ[env_var]
    if env_var in locals():
        return locals()[env_var]
    if env_var in globals():
        return globals()[env_var]
    return default


def get_all_scripts(script_dir,
                    logger=logging.getLogger('main')):
    """Retrieve all scripts in the specified directory."""
    r_scripts = glob(f'{script_dir}/*.R')
    logger.info(f'Retrieved R scripts {r_scripts}')
    py_scripts = glob(f'{script_dir}/*.py')
    logger.info(f'Retrieved Python scripts {py_scripts}')
    return r_scripts + py_scripts
