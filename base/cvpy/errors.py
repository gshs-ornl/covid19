#!/usr/bin/env python3
"""Contains errors class which will email information regarding errors."""
import logging
from datetime import datetime
from cvpy.common import check_environment as ce
from cvpy.emails import send_email as email_sender
# TODO probably add a metaclass for these


class ScriptError():
    """Standard error class for when a script errs out
       If a script exists with a non-zero status, it is considered failed.
       Output will be captured from the subprocess and placed here. """
    def __init__(self, script, text, timestamp=datetime.utcnow(),
                 email_recipients=['grantjn@ornl.gov', 'kaufmanjc@ornl.gov',
                                   'piburnjo@ornl.gov'],
                 production=ce('PRODUCTION', 'False'),
                 logger=logging.getLogger(ce('PY_LOGGER', 'main'))):
        """Initialize the error type."""
        if production == 'False':
            self.production = False
        elif production == 'True':
            self.production = True
        self.logger = logger
        self.emails = email_recipients
        self.script = script
        self.text = text
        self.timestamp = timestamp

    def email(self):
        """Send email to email recipients."""
        msg = f'Script {self.script} failed with message\r\n: {self.text}'
        if self.production:
            # TODO fill this in with proper logic
            self.logger.info(f'Sending email to {self.emails}')
            self.logger.info(f'Sending message\r\n: {msg}')
            email_sender(self.emails,
                         f'COVID19 Scrapers Error {self.timestamp}', msg)
            pass
        if not self.production:
            self.logger.info(f'Error message: {msg}')
            # Uncomment the code below to spam yourself with emails from your
            # local test instance.
            # email_sender(['<your_email_here@ornl.gov>'],
            #              f'COVID19 Scrapers Error {self.timestamp}', msg)
            # this will always pass, as we don't want to email if not in prod
            pass


class SlurpError():
    """Error class for when the slurper encounters an issue.

      If any exceptions are raised during slurp activities, this error is
      raised.
    """
    def __init__(self, script, text, timestamp=datetime.utcnow(),
                 email_recipients=['grantjn@ornl.gov', 'kaufmanjc@ornl.gov',
                                   'piburnjo@ornl.gov'],
                 production=ce('PRODUCTION', 'False'),
                 logger=logging.getLogger(ce('PY_LOGGER', 'main'))):
        """Initialize the SlurpError class."""
        if production == 'False':
            self.production = False
        elif production == 'True':
            self.production = True
        self.logger = logger
        self.emails = email_recipients
        self.script = script
        self.text = text
        self.timestamp = timestamp

    def email(self):
        """Send email to email recipients."""
        self.logger.info(f'Sending email to {self.emails}')
        msg = f'Script {self.script} failed with message: {self.text}'
        if self.production:
            logging.info(f'Sending message: {msg}')
            email_sender(self.emails,
                         f'COVID19 Scrapers Error {self.timestamp}', msg)
            pass
        if not self.production:
            # this will always pass, as we don't want to email if not in prod
            pass


class ErrorType:
    """Error types used when throwing custom exceptions."""
    Unknown = 'An unknown error occurred.'
    Script = 'An error occurred whiel running a script.'
    Slurp = 'An error was encountered while slurping the cleaned data.'
    Digest = 'An error occurrred while digesting.'
    Ingest = 'An error occurred while ingesting.'
    Glob = 'An error occurred while globbing for CSV files.'
    Database = 'An error occurred while using Database().'
    Image = 'An error occured while using ReadImage().'
    PDF = 'An error occurred while reading PDF.'
