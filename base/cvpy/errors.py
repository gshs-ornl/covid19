#!/usr/bin/env python3
"""Contains errors class which will email information regarding errors."""
import logging
from datetime import datetime
from cvpy.common import check_environment as ce
from cvpy.common import send_email as email_sender


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
        self.logger.info(f'Sending email to {self.emails}')
        msg = f'Script {self.script} failed with message: {self.text}'
        if self.production:
            # TODO fill this in with proper logic
            logging.info(f'Sending message: {msg}')
            pass
        if not self.production:
            # this will always pass, as we don't want to email if not in prod
            pass
