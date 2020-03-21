"""
This is the EAGLE-I package that contains the modules used by screen scrapers.
"""
import os
import sys
import time
import logging
import logging.config as LC
from cvr.static import Files as F
from cvr.static import Directories as D
from cvr.common import check_environment as ce
from cvr.logging import UTCFormatter, DictLogger


# find the desired logfile
LOG_FILE = ce('LOG_FILE', F.ETL_LOG)
ROTATE_LOG_FILE = ce('ROTATE_LOG', F.ROTATE_LOG)
LC.dictConfig(DictLogger.SIMPLE)
