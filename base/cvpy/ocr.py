#!/usr/bin/env python3
"""Provides methods for reading images and recognizing characters."""
import re
import logging
import pandas as pd
import urllib.request
from PIL import Image
from PIL import UnidentifiedImageError
from pytesseract import image_to_data
from pytesseract import Output
from urllib.error import HTTPError
from cvpy.common import check_environment as ce
from cvpy.static import ImageConfig, UrlRegex
from cvpy.exceptions import ReadImageException


class ReadImage():
    """Reads an image and recognizes the characters within it."""
    def __init__(self, image_file, timeout=0,
                 logger=logging.getLogger(ce('PY_LOGGER', 'main'))):
        """Initialize the ReadImage class with the provided info."""
        self.logger = logger
        self.timeout = timeout
        self.image_file = image_file
        try:
            try:
                if re.match(UrlRegex.RE, image_file):
                    self.image = Image.open(urllib.request.urlopen(image_file))
                else:
                    self.image = Image.open(self.image_file)
            except Exception as e:
                self.logger.info(f'Image was not a URL: {e}')
        except FileNotFoundError as e:
            msg = f'File {image_file} not found: {e}'
            self.logger.error(msg)
            raise ReadImageException(msg)
        except UnidentifiedImageError as e:
            msg = f'File {image_file} raised an error: {e}'
            self.logger.error(msg)
            raise ReadImageException(msg)
        except ValueError as e:
            msg = f'File {image_file} mode is not ' + \
                f'"r" or a StringIO was passed. {e}'
            self.logger.error(msg)
            raise ReadImageException(msg)
        except HTTPError as e:
            msg = f'URL {image_file} raised exception: {e}'
            self.logger.error(msg)
            raise ReadImageException(msg)
        except Exception as e:
            msg = 'An unexpected error was raised while processing ' + \
                f'{image_file}: {e}'
            self.logger.error(msg)
            raise ReadImageException(msg)

    def process(self):
        """Process the read image into a string."""
        try:
            self.text = image_to_data(self.image, lang='eng', nice=1,
                                      output_type=Output.DATAFRAME,
                                      timeout=self.timeout,
                                      pandas_config=ImageConfig.PD)
        except RuntimeError as e:
            msg = f'Image file {self.image_file} timed out with timeout of ' +\
                f'{self.timeout}. Consider increasing timeout. {e}'
            self.logger.error(msg)
            raise ReadImageException(msg)
        if isinstance(self.text, str):
            if self.text == '' or self.text is None:
                raise ReadImageException('No text was found in file ' +
                                         '{self.image_file}.')
            else:
                return(self.text)
        elif isinstance(self.text, pd.DataFrame):
            if self.text.empty:
                raise ReadImageException('No text was found in file ' +
                                         '{self.image_file}.')
            else:
                return(self.text)
        else:
            msg = f'Image file {self.image_file} returned an expected ' + \
                f'type: {type(self.text)}.'
            self.logger.error(msg)
            raise ReadImageException(msg)


class ReadPDF():
    """Provide module performing OCR for PDFs."""
    # TODO finish this
    pass
