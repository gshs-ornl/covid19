"""WARNING:
This module is deprecated in favor of db to db interaction or
submitting a file for slurp.
"""
from datetime import datetime
from hashlib import md5
from time import sleep
from typing import Dict, List, NoReturn, Union

import requests
from elasticsearch import Elasticsearch
from elasticsearch.helpers import bulk

from es_app.common import get_var, make_getter as mg

Entry = Dict[str, Union[str, int, float]]
Doc = Dict[str, Union[str, int, float, Dict]]

ESUSER: str = get_var('ESUSER', '')
ESPASS: str = get_var('ESPASS', '')
ESHOSTS: str = get_var('ESHOSTS', '')
ESINDEX: str = get_var('ESINDEX', 'covid19-ornl')
host_list: List[str] = ESHOSTS.split(',')
host_list: List[Dict] = [{'host': host} for host in host_list]

fips_skeleton: str = (
    "https://geo.fcc.gov/api/census/block/find"
    "?latitude={latitude}"
    "&longitude={longitude}"
    "&showall=false"
    "&format=json"
)


def get_elastic_client():
    tmp = Elasticsearch(
        hosts=host_list,
        http_auth=(ESUSER, ESPASS)
    )
    return tmp


class ElasticParse:
    _index = ESINDEX
    _type = 'record'
    _getters = {
        'access_time': mg('county_access_time', str),
        'active': mg('active', float),
        'age_cases': mg('age_cases', float),
        'age_deaths': mg('age_deaths', float),
        'age_deaths_percent': mg('age_deaths_percent', float),
        'age_hospitalized': mg('age_hospitalized', float),
        'age_hospitalized_percent': mg('age_hospitalized_percent', float),
        'age_negative': mg('age_negative', float),
        'age_negative_percent': mg('age_negative_percent', float),
        'age_percent': mg('age_percent', float),
        'age_range': mg('age_range', str),
        'age_tested': mg('age_tested', str),
        'cases': mg('cases', float),
        'cases_female': mg('cases_female', str),
        'cases_male': mg('cases_male', str),
        'confirmed': mg('???', float),
        'counties': mg('counties', float),
        'country': mg('ctry.country', str),
        'country3Letter': mg('???', str),
        'county': mg('county', str),
        'deaths': mg('deaths', float),
        'hospitalized': mg('hospitalized', float),
        'icu': mg('icu', float),
        'inconclusive': mg('inconclusive', float),
        'lab': mg('lab', str),
        'lab_negative': mg('lab_negative', float),
        'lab_positive': mg('lab_positive', float),
        'lab_tests': mg('lab_tests', float),
        'lastUpdate': mg('updated', float),
        'lat': mg('lat', float),
        'lon': mg('lon', float),
        'monitored': mg('monitored', float),
        'negative': mg('negative', float),
        'no_longer_monitored': mg('no_longer_monitored', float),
        'other': mg('other', str),
        'other_value': mg('other_value', str),
        'page': mg('page', str),
        'parish': mg('parish', str),
        'pending_tests': mg('pending', float),
        'presumptive': mg('presumptive', float),
        'private_test': mg('private_tests', float),
        'provider': mg('provider', str),
        'raw_page': mg('raw_page', str),
        'recovered': mg('recovered', float),
        'region': mg('region', str),
        'resolution': mg('resolution', str),
        'scrape_group': mg('sg.scrape_group', int, str),
        'severe': mg('severe', float),
        'sex': mg('sex', str),
        'sex_counts': mg('sex_counts', str),
        'sex_percent': mg('sex_percent', str),
        'state': mg('state', str),
        'state_test': mg('???', float),
        'tested': mg('tested', float),
        'updated': mg('updated', str),
        'url': mg('u.url', str)
    }

    def __init__(self, entries: List[Entry], op_type: str = 'index'):
        self.client = get_elastic_client()
        self._entries = entries
        if op_type not in ['index', 'create', 'update']:
            raise ValueError('Improper op_type given')
        self.op_type = op_type
        self.body_name = {
            'index': '_source',
            'create': '_source',
            'update': 'doc'
        }.get(self.op_type)

    @staticmethod
    def gen_id(entry: Entry) -> str:
        head = entry.get('county') or (entry.get('lat'), entry.get('lon'))
        if isinstance(head, tuple):
            head = ''.join(map(str, head))
        body = entry.get('state')
        tail = str(entry.get('scrape_group'))
        seed = ''.join((head, body, tail))
        return md5(seed.encode('utf-8')).hexdigest()

    @staticmethod
    def get_fips(lat: float, lon: float) -> Dict:
        fips_request = fips_skeleton.format(
            latitude=lat,
            longitude=lon
        )
        response = None
        attempts = 0
        while response is None:
            try:
                response = requests.get(fips_request)
            except requests.exceptions.RequestException:
                if attempts > 5:
                    raise
            else:
                if not 200 <= response.status_code < 300:
                    response = None
                else:
                    return response.json()
            sleep(pow(2, attempts))
            attempts += 1

    def entry_to_act(self, entry: Entry) -> Dict:
        doc: Doc = {key: val(entry) for key, val in self._getters.items()}
        lat = entry.get('lat')
        lon = entry.get('lon')
        if lat and lon:
            fips = self.get_fips(lat, lon)
            doc['fips'] = fips
            doc['geometry'] = {
                'coordinates': [lon, lat],
                'type': 'Point'
            }
        doc['createdAt'] = datetime.utcnow().timestamp()
        return {
            '_index': self._index,
            '_id': self.gen_id(entry),
            self.body_name: doc
        }

    def gen_actions(self) -> List[Dict]:
        actions = map(self.entry_to_act, self._entries)
        actions = list(actions)
        [act.update({'_op_type': self.op_type}) for act in actions]
        return actions

    def send_actions(self, actions: List[Dict] = None) -> NoReturn:
        if actions is None:
            actions = self.gen_actions()
        bulk(self.client, actions)
