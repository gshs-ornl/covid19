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


def test_checkbox():
    assert hasattr(interact, 'checkbox')
    checkbox = getattr(interact, 'checkbox')
    assert callable(checkbox)
    assert checkbox("sample") == sample_checkbox_checked
    assert checkbox("sample", False) == sample_checkbox_unchecked
