from os import environ
from typing import Any, Dict, List

from flask import Flask, request
from elasticsearch import Elasticsearch
from elasticsearch.helpers import bulk


def get_var(env_var: str, default: Any = None) -> Any:
    """Scans environment locations for variable
    Checks in order:
        os.environ
        locals()
        globals()

    :param env_var: Name of variable for grabbing
    :param default: Value to return if variable not found
    :return: value of variable or default
    """
    if res := environ.get(env_var):
        return res
    if res := locals().get(env_var):
        return res
    if res := globals().get(env_var):
        return res
    return default
