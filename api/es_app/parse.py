from typing import List, Dict

from elasticsearch import Elasticsearch
from elasticsearch.helpers import bulk

from es_app.common import get_var


KNOWN_ATTRS = {
    'access_time': int,
    'cases': float,
    'confirmed': float,
    'counties': float,
    'country/region': str,
    'country3Letter': str,
    'county': float,
    'createdAt': float,
    'deaths': float,
}
