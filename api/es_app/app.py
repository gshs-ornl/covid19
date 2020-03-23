from os import environ
from typing import Any, Dict, List

from flask import Flask, request

from .common import get_var


flask_app_name = get_var('FLASK_APP_NAME', 'es_app')
flask_debug = get_var('FLASK_DEBUG', True)

app = Flask(flask_app_name, static_url_path='')
