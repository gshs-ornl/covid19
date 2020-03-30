#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Sets up logging for the package to use

example:

"""
import sys
import time
import logging
import traceback
import multiprocessing
import logging.config
from threading import Thread
from cvpy.static import LoggingInfo
from cvpy.static import Files
from logging.handlers import RotatingFileHandler


class UTCFormatter(logging.Formatter):
    """ make a time formatter for UTC """
    converter = time.gmtime


class MultiprocessLogging(logging.Handler):
    """ create a multiprocessing logger which can collect the logs
        from spawned processes
    """
    def __init__(self, name, mode, maxsize, rotate, filename=Files.ROTATE_LOG):
        logging.Handler.__init__(self)
        self._handler = RotatingFileHandler(filename=filename)
        self.queue = multiprocessing.Queue(-1)
        t = Thread(target=self.receive)
        t.daemon = True
        t.start()

    def setFormatter(self, fmt=LoggingInfo.FORMAT):
        logging.Handler.setFormatter(self, fmt)
        self._handler.setFormatter(self, fmt)

    def receive(self):
        while True:
            try:
                record = self.queue.get()
                self._handler.emit(record)
            except (KeyboardInterrupt, SystemExit):
                raise
            except EOFError:
                break
            except Exception:
                traceback.print_exc(file=sys.stderr)

    def send(self, s):
        self.queue.put_nowait(s)

    def _format_record(self, record):
        if record.args:
            record.msg = records.msg % records.args
            record.args = None
        if record.exe_info:
            dummy = self.format(record)
            record.exc_info = None
        return record

    def emit(self, record):
        try:
            s = self._format_record(record)
            self.send(s)
        except (KeyboardInterrupt, SystemExit):
            raise
        except Exception:
            self.handleError(record)

    def close(self):
        self._handler.close()
        logging.Handler.close(self)


class ServerLogging(logging.Handler):
    """ this is todo, as we will eventually want a server<--client
        method
    """
    pass


class ClientLogging(logging.Handler):
    """ this is todo, as we will eventually want a server<--client
        method
    """
    pass


class DictLogger:
    LOGGING = {
        'version': 1,
        'disable_existing_loggers': False,
        'formatters': {
            'utc': {
                '()': UTCFormatter,
                'format': LoggingInfo.MASTERFORMAT,
                'datefmt': LoggingInfo.DATEFMT},
            'local': {
                '()': UTCFormatter,
                'format': LoggingInfo.SHORT_FORMAT,
                'datefmt': LoggingInfo.DATEFMT},
            'server': {
                '()': UTCFormatter,
                'format': LoggingInfo.ROTATE_FORMAT,
                'datefmt': LoggingInfo.DATEFMT}
        }, 'handlers': {
            'console': {
                'class': 'logging.StreamHandler',
                'formatter': 'local',
                'stream': 'ext:://sys.stdout'},
            'file': {
                'class': 'logging.FileHandler',
                'filename': "LOG_FILE",
                'formatter': 'utc'},
            'rotate': {
                'class': 'logging.handlers.RotatingFileHandler',
                'formatter': 'server',
                'filename': Files.ROTATE_LOG,
                'maxBytes': 500000,
                'backupCount': 1000}
        }, 'loggers': {
            'server': {
                'handlers': ['rotate'],
                'level': 'INFO'},
            'main': {
                'handlers': ['console'],
                'level': 'INFO',
                'propogate': True},
            'root': {
                'handlers': ['console', 'rotate'],
                'level': 'INFO'},
            'debug': {
                'handlers': ['console', 'file'],
                'level': 'DEBUG',
                'propogate': True}
        }}
    SIMPLE = {
        'version': 1,
        'disable_existing_loggers': False,
        'formatters': {
            'utc': {
                '()': UTCFormatter,
                'format': LoggingInfo.FORMAT,
                'datefmt': LoggingInfo.DATEFMT},
            'complete': {
                '()': UTCFormatter,
                'format': LoggingInfo.MASTERFORMAT,
                'datefmt': LoggingInfo.DATEFMT}},
        'handlers': {
            'console': {
                'class': 'logging.StreamHandler',
                'formatter': 'complete',
                'stream': 'ext://sys.stdout'},
            'file': {
                'class': 'logging.FileHandler',
                'filename': Files.LOG_FILE,
                'formatter': 'utc'},
            'rotate': {
                'class': 'logging.handlers.RotatingFileHandler',
                'formatter': 'utc',
                'filename': Files.ROTATE_LOG,
                'maxBytes': 500000,
                'backupCount': 1000}},
        'loggers': {
            'main': {
                'handlers': ['console'],
                'level': 'INFO'},
            'debug': {
                'handlers': ['console', 'file'],
                'level': 'DEBUG'},
            'root': {
                'handlers': ['console', 'rotate']}}}
