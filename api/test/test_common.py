from os import environ

from es_app import common


def test_get_var():
    assert hasattr(common, 'get_var')
    get_var = getattr(common, 'get_var')
    assert callable(get_var)
    assert get_var('NOT_EXISTS') is None
    assert get_var('NOT_EXISTS', 1)
    environ['TEST_ENVIRON'] = 'True'
    assert get_var('TEST_ENVIRON') == 'True'
