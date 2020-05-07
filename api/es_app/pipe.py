from datetime import datetime
from hashlib import md5
from typing import Dict, List, NoReturn, Union

from elasticsearch import Elasticsearch
from elasticsearch.helpers import bulk
import psycopg2
import requests

from es_app.common import Backoff, get_var, make_getter as mg

ESUSER: str = get_var('ESUSER', '')
ESPASS: str = get_var('ESPASS', '')
ESHOSTS: str = get_var('ESHOSTS', '')
ESINDEX: str = get_var('ESINDEX', 'covid19-custom-ornl')
host_list: List[Dict[str, str]] = [
    {'host': host} for host in ESHOSTS.split(',')
]

PGUSER: str = get_var('PGUSER', '')
PGPASS: str = get_var('PGPASS', '')
PGDB: str = get_var('PGDB', '')
PGHOST: str = get_var('PGHOST', '')
PGPORT: str = get_var('PGPORT', '5432')

fips_api: str = (
    'https://geo.fcc.gov/api/census/block/find?'
    'latitude={latitude}'
    '&longitude={longitude}'
    '&showall=false'
    '&format=json'
)


def gen_es_client() -> Elasticsearch:
    return Elasticsearch(
        hosts=host_list,
        http_auth=(ESUSER, ESPASS)
    )


def gen_pg_client():
    return psycopg2.connect(
        dbname=PGDB,
        user=PGUSER,
        password=PGPASS,
        host=PGHOST,
        port=PGPORT
    )


@Backoff(requests.exceptions.RequestException)
def get_fips(lat: float, lon: float) -> Dict[str, ...]:
    url = fips_api.format(
        latitude=lat,
        longitude=lon
    )
    response = requests.get(url)
    response.raise_for_status()
    return response.json()
