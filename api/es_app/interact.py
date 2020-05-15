import csv
from io import StringIO
from struct import pack
from time import time
from typing import Generator, Iterable, Tuple
import zlib

import flask_table
import psycopg2

from es_app.common import get_var

try:
    from cvpy.database import Database
except ModuleNotFoundError:
    Database = None

PGUSER: str = get_var('PGUSER', '')
PGPASS: str = get_var('PGPASS', '')
PGDB: str = get_var('PGDB', '')
PGHOST: str = get_var('PGHOST', '')
PGPORT: str = get_var('PGPORT', '5432')


page_skeleton = """
<!doctype html>
<h1>nsetcovid19 Data View and Export</h1>
<br>
<form method=post>
    <fieldset>
    <legend>Column Selection</legend>
        {checkboxes}
        <br>
        <div>
            <button type="submit" value="Submit">Filter columns</button>
            <input type="radio" id="view" name="mode" value='view' checked>
            <label for="view">View</label>
            <input type="radio" id="gzip" name="mode" value='gzip'>
            <label for="gzip">gzip CSV</label>
        </div>
    </fieldset>
</form>
<br>
{table}
-----Truncated-----
"""


def checkbox(name: str, checked: bool = True) -> str:
    """Generates basic checkbox html

    :param name: name assigned to checkbox field
    :param checked: checked status on creation
    :return: generated html text
    """
    _check = 'checked' if checked else ''
    _input = f'type="checkbox" name="{name}" value="checked" {_check}'
    _label = f'<label for="{name}">{name}</label>'
    body = (
        '<div>\n'
        f'    <input {_input}>\n'
        f'    {_label}\n'
        '</div>'
    )
    return body


def gen_table(name: str, *columns: str, **kwargs) -> flask_table.Table:
    """Wrapper around flask_table.create_table for easier
    dynamic generation

    :param name: table name
    :param columns: column names in table as separate args
    :param kwargs: any arguments to be passed to create_table
    :return: generated html table
    """
    table = flask_table.create_table(name=name, **kwargs)
    for col in columns:
        table.add_column(col.lower(), flask_table.Col(col))
    return table


# TODO: Move this to common
def gen_db_client():
    """Using environment variables, create database connection

    If cvpy is not installed, defaults to standard psycopg2

    :return: connection object or cvpy Database object
    """
    if Database is None:
        return psycopg2.connect(
            dbname=PGDB,
            user=PGUSER,
            password=PGPASS,
            host=PGHOST,
            port=PGPORT
        )
    tmp = Database()
    tmp.open()
    tmp.cursor = tmp.con.cursor
    return tmp


def gen_data(query: str, chunk: int = 500) -> Generator[Tuple]:
    """Pulls data from connection made by db_client and steps
    through it

    :param query: query text sent to client
    :param chunk: numbers of rows to pull at one time
    :return: generator of all data pulled
    """
    client = gen_db_client()
    cursor = client.cursor(name='export-provider')
    cursor.execute(query)
    _rows = (cursor.fetchone(),)
    yield tuple((col.name for col in cursor.description))
    while _rows:
        yield from _rows
        _rows = cursor.fetchmany(chunk)
    cursor.close()
    client.close()


def stream_csv(stream: Iterable) -> Generator[str]:
    """Converts iterable of iterables to lines of a csv file

    :param stream: iterable of iterables for conversion
    :return: generator of all lines converted
    """
    output: StringIO = StringIO()
    for row in stream:
        writer = csv.writer(output, quoting=csv.QUOTE_ALL)
        writer.writerow(row)
        yield output.getvalue()
        output = StringIO()


def stream_gzip(stream: Iterable[str]) -> Generator[bytes]:
    """Compresses iterable of strings to gzip file

    :param stream: iterable of strings to be written to file
    :return: generator of lines to compressed data for writing
    """
    yield bytes([
        0x1F, 0x8B, 0x08, 0x00,
        *pack('<L', int(time())),
        0x02, 0xFF,
    ])
    # gzip magic numbers
    zipper = zlib.compressobj(
        9,
        zlib.DEFLATED,
        -zlib.MAX_WBITS,
        zlib.DEF_MEM_LEVEL
    )
    crc = zlib.crc32(b'')
    data_len = 0
    for line in stream:
        data = line.encode('utf-8')
        chunk = zipper.compress(data)
        if chunk:
            yield chunk
        crc = zlib.crc32(data, crc) & 0xFFFFFFFF
        data_len += len(data)
    yield zipper.flush()
    yield pack('<2L', crc, data_len & 0xFFFFFFFF)
