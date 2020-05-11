import flask_table

from es_app import interact


sample_checkbox_checked = '''
<div>
    <input type="checkbox" name="sample" value="checked" checked>
    <label for="sample">sample</label>
</div>
'''.strip()
sample_checkbox_unchecked = '''
<div>
    <input type="checkbox" name="sample" value="checked" >
    <label for="sample">sample</label>
</div>
'''.strip()
sample_table_data = [
    {'name': f'name{i}', 'description': f'description{i}'}
    for i in range(10)
]


def test_checkbox():
    assert hasattr(interact, 'checkbox')
    checkbox = getattr(interact, 'checkbox')
    assert callable(checkbox)
    assert checkbox("sample") == sample_checkbox_checked
    assert checkbox("sample", False) == sample_checkbox_unchecked


def test_gen_table():
    assert hasattr(interact, 'gen_table')
    gen_table = getattr(interact, 'gen_table')
    assert callable(gen_table)
    test_table = flask_table.create_table(
        'test_table',
        options={'border': '1px solid black'}
    )
    test_table.add_column('name', flask_table.Col('Name'))
    test_table.add_column('description', flask_table.Col('Description'))
    test_table_html = test_table(sample_table_data).__html__()
    gen_test_table = gen_table(
        'test_table',
        'Name',
        'Description',
        options={'border': '1px solid black'}
    )
    gen_test_table_html = gen_test_table(sample_table_data).__html__()
    assert test_table_html == gen_test_table_html
