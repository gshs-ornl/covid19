#!/usr/bin/env python3
"""Digest the CSVs in the $OUTPUT_DIR and output to the $INPUT_DIR."""
from glob import glob
from cvpy.digester import Digest
from cvpy.common import check_environment as ce

input_dir = ce('INPUT_DIR', '/tmp/input')
output_dir = ce('OUTPUT_DIR', '/tmp/output')


if __name__ == "__main__":
    """Run the digester, which takes the aggregate CSVs from the $OUTPUT_DIR,
       cleans and aggregates them, and then writes them to the $CLEAN_DIR."""
    pass
