#!/usr/bin/env python3
""" imports all csvs in the output directory """
import os
import csv
import sys
import glob
import traceback
import pandas as pd
from cvpy.database import Database as DB
from cvpy.common import check_environment as ce
from cvpy.static import Headers as H

class Ingest():
    """ ingests all csvs in the output directory """
    def __init__(logger=logging.getLogger('main')):
        self.logger = logger
        self.output_dir = ce('OUTPUT_DIR', '/tmp/output/')
        self.csv_list =  glob.glob(self.output_dir + '*.csv')

    def combine_csvs(self):
        df_all = pd.DataFrame
        for csv in csv_list:
            df = pd.read_csv(csv)
            df_all = pd.concat([df_all, df], axis = 0, ignore_index = TRUE)




