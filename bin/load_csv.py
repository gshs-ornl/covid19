#!/usr/bin/env python

#
# Test program for loading CSV file into the new databse schema
#

import sys
import os
import os.path
import glob
import re
import psycopg2
import zipfile
import io
import datetime
import collections
import fnmatch
import pathlib
import logging
import argparse
from cvpy.database import Database
from cvpy.csvloader import CSVLoader

parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter, description="Loader of CSV scrapes into the new schema")

parser.add_argument("files", type=str, nargs='+', help="CSV files, zip archives, or directories to load; inside zip use name.zip:name.csv")
parser.add_argument("--dsn", help="database to load CSVs to", type=str, default="postgresql://ingester:AngryMoose@localhost:5432/covidb")
parser.add_argument("--schema", help="database schema to load data to", type=str, default='staging')
parser.add_argument("--op", help="operation ('replace' will remove all records for the specific file before appending)", type=str, choices=['append', 'replace', 'new'], default='append')
parser.add_argument("--exclude", help="exclude specified CSVs and zips from processing (globs Ok)", nargs='*', type=str, default=[])
parser.add_argument("--start", help="start processing with the specified CSV or zip (must be an exact match)", type=str)
parser.add_argument("--rows", help="load only specified rows, e.g., -10,11-13,15,17- (use =, intervals inclusive, all files, start row=0, header ignored)", type=str)
parser.add_argument("--datadir", "-C", help="directory with the data", default=".", type=pathlib.Path)
parser.add_argument("--logdir", help="directory for log files", default="logs", type=pathlib.Path)
parser.add_argument("--batch", help="CSV batch name", default=datetime.datetime.now().replace(microsecond=0).isoformat(), type=str)
parser.add_argument("-k", "--dry-run", action="count", default=0, help="dry run, add more k to do more")
parser.add_argument("-v", "--verbosity", action="count", default=0, help="add more v to increase verbosity, e.g., -vvvv")

args = parser.parse_args()

print(f"Loading from {args.files} to {args.dsn} schema={args.schema}")

logdir = pathlib.Path(args.logdir, args.batch)
logdir.mkdir(parents=True, exist_ok=True)

# logging for bulk errors
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
con_h = logging.StreamHandler(sys.stdout)
if args.verbosity == 0:
    con_h.setLevel(logging.CRITICAL)
elif args.verbosity == 1:
    con_h.setLevel(logging.ERROR)
elif args.verbosity == 2:
    con_h.setLevel(logging.INFO)
elif args.verbosity > 2:
    con_h.setLevel(logging.DEBUG)
logger.addHandler(con_h)

def lno():
    """current line number (for debugging)
    :returns: file name and line number

    """
    return sys.argv[0] + ':' + str(inspect.currentframe().f_back.f_lineno)

def is_good_csv_name(s):
    """Check if the file name look like a good CSV, avoid system and hidden files.

    :s: file name to check
    :returns: True or False

    """

    return s.lower().endswith(".csv") \
        and not "__MACOSX/" in s \
        and not "/." in s \
        and not s.startswith(".")

def next_csv():
    """returns next available CSV

    will use files.args
    if directory -- globs all CSV file
    if CSV file -- process
    if zip file -- process all CSV files in it
    :returns: stream with a CSV, file name

    """

    # creating a lisy of included files
    excl = {}
    for ff in args.exclude:
        ff_parts = re.split("(\.zip):", ff, maxsplit=3, flags=re.IGNORECASE)
        ff_zip = ff_parts[0] + (ff_parts[1] if len(ff_parts) > 1 else '')
        if not ff_zip in excl:
            excl[ff_zip] = []
        if len(ff_parts) > 2:
            excl[ff_zip].append(ff_parts[2])

    # TODO: support globs in args.files
    for ff in [ pathlib.PurePath(args.datadir, p) for p in args.files ]:

        if any([fnmatch.fnmatch(ff, ef) for ef in args.exclude]): # GLOBS!!
            print(f"Skipping excluded file {ff}...")
            continue

        if os.path.isdir(ff):
            print(f"Looking for CSV files in dir {ff} ...")
            for fn in glob.glob(str(ff) + "/*.csv") + glob.glob(str(ff) + "/*.CSV") :
                if any([fnmatch.fnmatch(fn, ef) for ef in args.excludei]):
                    print(f"Skipping excluded file {ff}...")
                else:
                    yield open(fn, "r", encoding='utf-8-sig', errors='replace'), fn

        elif ff.suffix.lower() == ".csv":
            yield open(ff, "r", encoding='utf-8-sig', errors='replace'), ff

        # TODO: option to select a file inside a zip
        elif ff.suffix.lower() == ".zip" or re.search(".zip:", ff, flags=re.IGNORECASE):

            # extrascting zip and csv fnames for synatx like x.zip:y.csv
            ff_parts = re.split("(\.zip):", str(ff), flags=re.IGNORECASE)
            ff_zip = ff_parts[0] + ( ff_parts[1] if len(ff_parts) > 1 else '' )
            ff_csv = ff_parts[2] if len(ff_parts) > 2 else None

            # excludes
            excl_ent = next((fe for fe in excl.keys() if fnmatch.fnmatch(ff_zip, fe)), None)
            if excl_ent and not excl[excl_ent]: # empty list of files in the archive
                print(f"Skipping {ff_zip} (glob {excl_ent})")
                continue

            with zipfile.ZipFile(ff_zip, "r") as zf:
                for fn in [fn for fn in zf.namelist() if is_good_csv_name(fn)]:
                    if not ff_csv or fnmatch.fnmatch(fn, ff_csv):
                        if excl_ent and any([fnmatch.fnmatch(fn, fe) for fe in excl[excl_ent]]):
                            print(f"Skipping {ff_zip}:{fn} (glob {excl_ent}:{excl[excl_ent]})")
                        elif any([fnmatch.fnmatch(fn, fe) for fe in args.exclude]):
                            print(f"Skipping {ff_zip}:{fn} (glob in {args.exclude}")
                        else:
                            with zf.open(fn) as csvh:
                                yield io.TextIOWrapper(csvh, encoding='utf-8-sig', errors='replace'), f"{ff}:{fn}"
        else:
            print(f"Do not know what to do with {ff}")

# parser for row selector
rows = []
if args.rows:
    for r in (r.split('-') for r in args.rows.split(",")):
        if len(r) == 1:
            rows.append((int(r[0]),))
        else:
            rows.append(( int(r[0]) if r[0] else 0, int(r[1]) if r[1] else sys.maxsize ))

    rows.sort(key=lambda _ : _[0])

with Database(dsn=args.dsn) as db:

    logfh = None
    csvloader = CSVLoader(db, dry_run=args.dry_run)

    for csv_stream, fname in next_csv():

        if args.start and args.start == fname:
            args.start = None

        if args.start:
            print(f"Skipping before start {fname}")
            continue

        # open CSV-file specific log file
        if not logfh is None:
            logger.removeHandler(logfh)

        fname_log = pathlib.Path(\
             logdir,\
             str(pathlib.Path(fname).relative_to(args.datadir)).replace('/', '%').replace('..','')\
        ).with_suffix(".log")
        print(f"Logging into {fname_log}...")
        logfh = logging.FileHandler(fname_log)
        logfh.setLevel(logging.DEBUG)
        logger.addHandler(logfh)
        logger.info("Parsing {} started at {}".format(fname, datetime.datetime.now().isoformat()) )

        try:
            print(f"Loading {fname}")

            csvloader.load(csv_stream, op=args.op, logger=logger, rows=rows)

            print(f"Finished {fname}")

        except IOError as e:
            logger.error(f"Failure in {fname}: {e}")
        except zipfile.BadZipfile as e:
            logger.error(f"Bad zip, skipping the rest of {fname} after line {row_no}: {e}")

conn.commit()

conn.close()

