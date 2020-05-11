import csv
from io import StringIO
from struct import pack
from time import time
import zlib

import flask_table


def checkbox(name: str, checked: bool = True) -> str:
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
    table = flask_table.create_table(name=name, **kwargs)
    for col in columns:
        table.add_column(col.lower(), flask_table.Col(col))
    return table
