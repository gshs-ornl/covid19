from typing import Callable, List, Dict, Union

from elasticsearch import Elasticsearch
from elasticsearch.helpers import bulk

from es_app.common import eval_list, get_var

Table = Dict[str, Union[List, str]]

ESUSER: str = get_var('ESUSER', '')
ESPASS: str = get_var('ESPASS', '')
ESHOSTS: str = get_var('ESHOSTS', '')
ESINDEX: str = get_var('ESINDEX', 'covid-ornl')
host_list: List[str] = ESHOSTS.split(',')


def get_elastic_client():
    tmp = Elasticsearch(
        hosts=host_list,
        http_auth=(ESUSER, ESPASS)
    )
    return tmp


class ElasticParse:

    sep: str = ','
    es_type_map: Dict[str, Callable] = {
        'date': int,
        'long': float,
        'text': str,
    }

    def __init__(self, table: Table, sep: str = None):
        self.raw_table = table
        self.parsed_table = dict()
        if sep is not None:
            self.sep = sep
        for key, val in self.raw_table.items():
            if isinstance(val, list):
                self.parsed_table[key] = val
            elif isinstance(val, str):
                self.parsed_table[key] = val.split(self.sep)
            else:
                raise ValueError("Unexpected json value format")
        self.client = get_elastic_client()
        self.index_map = self.client.indices.get_mapping(ESINDEX)
        self.field_mappings = self.index_map.get(
            ESINDEX
        ).get(
            'mappings'
        ).get(
            'record'
        ).get(
            'properties'
        )

    def generate_actions(self, op_type: str = 'index') -> List[Dict]:
        if op_type not in ['index', 'create', 'update', 'delete']:
            raise ValueError('Operation not supported by bulk')
        self._cast_columns()

    def _cast_columns(self):
        gen_table = dict()
        for key, val in self.parsed_table.items():
            if key not in self.field_mappings:
                gen_table[key] = val
            elif key == 'scrape_group':
                gen_table[key] = list(map(str, val))
            else:
                elastic_type = self.field_mappings[key].get('type')
                caster = self.es_type_map.get(elastic_type)
                gen_table[key] = list(map(caster, val))
        self.parsed_table = gen_table
