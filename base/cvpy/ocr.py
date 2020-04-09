#!/usr/bin/env python3
"""Provides methods for reading images and recognizing characters."""
import logging
import pytesseract
from PIL import Image
from cvpy.common import check_environment as ce
from cvpy.logging import DictLogger

class ReadImage():
    """Reads an image and recognizes the characters within it."""
    def __init__(image_file,
                 logger=logging.getLogger(ce('PY_LOGGER', 'main'))):
        pass
