#!/usr/bin/env python3
"""Contains common functions used throughout the cvpy package."""
import os
import logging
from glob import glob
from cvpy.errors import ScriptError
from tempfile import TemporaryFile
from subprocess import check_output, CalledProcessError
# Import the email modules we'll need
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart


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
                    logger=logging.getLogger(
                        check_environment('PY_LOGGER', 'main'))):
    """Retrieve all scripts in the specified directory."""
    r_scripts = glob(f'{script_dir}/*.R')
    logger.info(f'Retrieved R scripts {r_scripts}')
    py_scripts = glob(f'{script_dir}/*.py')
    logger.info(f'Retrieved Python scripts {py_scripts}')
    return r_scripts + py_scripts


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

def send_email(email_recipients, subject, message_text):
    """ Send email to the recipients with the given subject and message body
    text

    :param text:
    :param text:
    :param subject:
    :param args:
    :return:
    """

    fromaddr = "covid19scrapers@ornl.gov"
    toaddr = email_recipients
    msg = MIMEMultipart()
    msg['Subject'] = subject
    msg.attach(MIMEText(message_text, 'plain'))

    server = smtplib.SMTP('smtp.ornl.gov', 25)
    text = msg.as_string()
    server.sendmail(fromaddr, toaddr, text)
    server.quit()
