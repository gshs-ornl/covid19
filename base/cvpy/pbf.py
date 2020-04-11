#!/usr/bin/env python3
"""Contains modules for handling PBF files."""
import random
import string
import requests
from cvpy.common import check_environment as ce


class ReadPBF():
    """Read in a PBF and decode with tippecanoe."""
    TIPPECANOE_DECODE = '/usr/local/bin/tippecanoe-decode'
    OUTPUT_DIR = ce('PIC_DIR', '/tmp/screenshots')
    def __init__(self, url):
        """Pull down a PBF file and decode to GeoJSON."""
        pbf_filename = self.OUTPUT_DIR + '/'
        pbf_filename += ''.join(random.choices(string.ascii_lowercase), k=7)
        pbf_filename += '.pbf'
        pbf_file = requests.get(url, allow_redirects=True)
        open(pbf_filename, 'wb').write(pbf_file.content)
        cmd = [TIPPECANOE_DECODE, pbf_file]
