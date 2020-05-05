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
