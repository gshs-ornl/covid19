#!/usr/bin/env python3
"""Contains email-related functions."""
# Import the email modules we'll need
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart


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
