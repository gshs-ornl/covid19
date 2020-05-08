from datetime import datetime
from hashlib import md5
from typing import Any, Callable, Dict, Generator, List

from elasticsearch import Elasticsearch
from elasticsearch.helpers import streaming_bulk
import psycopg2
from psycopg2.extras import RealDictCursor
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


TCFG = Dict[str, Callable[[Dict[str, Any]], Any]]


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
def get_fips(lat: float, lon: float, scope: int = 1) -> Dict[str, ...]:
    url = fips_api.format(
        latitude=lat,
        longitude=lon
    )
    response = requests.get(url)
    response.raise_for_status()
    resj = response.json()
    if scope < 2 and 'Block' in resj:
        del resj['Block']
    if scope < 1 and 'County' in resj:
        del resj['State']
    return resj


def dt_to_str(item: datetime) -> str:
    return item.isoformat()


def access_to_scrape(item: datetime) -> str:
    return item.strftime('%Y%m%d%H')


def county_gen_id(item: Dict[str, ...]) -> str:
    head = dt_to_str(item.get('access_time'))
    raw = head + ''.join([
        item.get(key, '') for key in
        ['country', 'state', 'county_name']
    ])
    return md5(raw.encode('utf-8')).hexdigest()


pg_to_es_county_config: TCFG = {
    'access_time': mg('access_time', dt_to_str),
    'cases': mg('cases', int),
    'cases_female': mg('sex_female_cases', float),
    'cases_male': mg('sex_male_cases', float),
    'country': mg('country', str),
    'county': mg('county_name', str),
    'deaths': mg('deaths', int),
    'hospitalized': mg('hospitalized', int),
    'inconclusive': mg('inconclusive', int),
    'lat': mg('county_lat', float),
    'lon': mg('county_lon', float),
    'monitored': mg('monitored', int),
    'negative': mg('negative', int),
    'no_longer_monitored': mg('no_longer_monitored', int),
    'pending': mg('pending', float),
    'recovered': mg('recovered', int),
    'scrape_group': mg('access_time', access_to_scrape),
    'state': mg('state', str),
    'tested': mg('tested', int),
    'updated': mg('updated', dt_to_str)
}


class Pipe:
    _op_type: str = 'index'
    _index: str = ESINDEX
    _id_gen: Callable[[Dict], str] = county_gen_id
    transform_config: TCFG = pg_to_es_county_config

    def __init__(self, limit: int = -1):
        self.limit: int = limit
        self.transfer_count: int = 0

    def gen_data_source(self, chunk_size: int = 500) -> Generator:
        pg_connect = gen_pg_client()
        pg_cursor = pg_connect.cursor(
            name='data-pipe-cur',
            cursor_factory=RealDictCursor
        )
        pg_cursor.execute('select * from public.get_ps_data()')
        _data_stream = True
        if self.limit == -1:
            while _data_stream:
                _data_stream = pg_cursor.fetchmany(chunk_size)
                yield from map(dict, _data_stream)
        else:
            while _data_stream and self.transfer_count < self.limit:
                _data_stream = pg_cursor.fetchmany(chunk_size)
                for item in map(dict, _data_stream):
                    yield item
                    self.transfer_count += 1
                    if self.transfer_count >= self.limit:
                        break

    def _transform_data_to_document(self,
                                   data_point: Dict,
                                   lat_name: str = 'lat',
                                   lon_name: str = 'lon') -> Dict:
        doc = dict()
        for key, val in self.transform_config.items():
            doc[key] = val(data_point)
        geo_check = all([
            lat_name in doc,
            doc.get(lat_name) is not None,
            lon_name in doc,
            doc.get(lon_name) is not None,
        ])
        if geo_check:
            doc['fips'] = get_fips(lat=doc[lat_name], lon=doc[lon_name])
            doc['geometry'] = {
                'coordinates': {
                    'lat': doc[lat_name],
                    'lon': doc[lon_name]
                },
                'type': 'Point'
            }
        doc['provider'] = 'state'
        doc['createdAt'] = datetime.utcnow().isoformat()
        return doc

    def gen_action_from_data(self, data_point: Dict) -> Dict:
        return {
            '_op_type': self._op_type,
            '_index': self._index,
            '_id': county_gen_id(data_point),
            '_source': self._transform_data_to_document(data_point)
        }

    def flow(self, chunk_size: int = 500):
        source = map(self.gen_action_from_data, self.gen_data_source(chunk_size))
        sink = streaming_bulk(gen_es_client(), source, chunk_size)
        for item in sink:
            if item:
                print(item)
