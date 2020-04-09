#!/usr/bin/env python3
"""Provide a script that parses Kansas."""
import time
import logging
import pandas as pd
from tempfile import TemporaryFile
from cvpy.common import check_environment as ce
from cvpy.webdriver import WebDriver
from cvpy.logging import DictLogger
from cvpy.ocr import ReadImage

logging.config.dictConfig(DictLogger.SIMPLE)
logger = logging.getLogger(ce('PY_LOGGER', 'main'))
output_dir = ce('OUTPUT_DIR', '/tmp/output')
url = 'https://public.tableau.com/profile/kdhe.epidemiology#' + \
    '!/vizhome/COVID-19Data_15851817634470/KSCOVID-19CaseData'

if __name__ == "__main__":
    with WebDriver(url=url, logger=logger, timeout=60, implicit_wait=30) as wb:
        wb.wait_for_element('//*[@id="title45763612845643606_' +
                            '4681463620239426524"]/div[1]', 'xpath',
                            wait=60)
        time.sleep(5)
        image_file_1 = wb.take_screenshot(temp_image_file)
        logger.info(f'Image saved as {image_file_1}')
        xpath2 = '//*[@id="view45763612845643606_' + \
            '9530241477442851964"]/div[1]'
        wb.wait_for_element(xpath2, 'xpath', 60)
        temp_image_file2 = TemporaryFile(dir='/mnt/forbin/', suffix='.png')
        image_file_2 = wb.take_screenshot(temp_image_file2)



