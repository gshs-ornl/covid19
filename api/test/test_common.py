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


def test_make_getter():
    assert hasattr(common, 'make_getter')
    make_getter = getattr(common, 'make_getter')
    assert callable(make_getter)
    test_dict = {
        'str': 'str',
        'int': '1',
        'float': '1.0',
    }
    str_getter = make_getter('str', str)
    assert callable(str_getter)
    assert str_getter(test_dict) == 'str'
    int_getter = make_getter('int', int)
    assert int_getter(test_dict) == 1
    float_getter = make_getter('float', float)
    assert float_getter(test_dict) == 1.0
    def_getter = make_getter('def', str)
    assert def_getter(test_dict) is None
    assert def_getter(test_dict, 'thing') == 'thing'
