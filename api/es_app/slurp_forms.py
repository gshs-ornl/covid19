import csv
from os import path
import zipfile

from werkzeug.utils import secure_filename
import xlrd

from es_app.common import get_var

try:
    from cvpy.slurper import Slurp
except ModuleNotFoundError:
    def identity(x):
        return x
    Slurp = identity


csv_dir = get_var('CSV_DIR', '/tmp/input')
file_chunk_size = 1000

slurp_html = """
    <!doctype html>
    <h1>covid-19_scrapers</h1>
    <h2>Upload Input Files</h2>
    <p>Please select the file to upload.</p>
    <form method=post enctype=multipart/form-data>
        <p>File Type</p>
        <input type="radio" id="csv" name="mode" value='csv' checked>
        <label for="view">CSV</label>
        <input type="radio" id="excel" name="mode" value='excel'>
        <label for="csv">Excel</label>
        <input type="radio" id="zip-csv" name="mode" value='zip-csv'>
        <label for="view">Zipped (specifically .zip) CSV</label>
        <input type="radio" id="zip-excel" name="mode" value='zip-excel'>
        <label for="csv">Zipped (specifically .zip) Excel</label>
        <input type=file name=CSVFile>
        <br><br>
        <input type=submit value=Upload>
    </form>
    <h2>Once submitted, do not close the browser window!</h2>
    <p>You should see a message upon completion</p>
    </html>

"""


def slurp_csv(file, filename):
    _name = secure_filename(filename)
    _path = path.join(csv_dir, _name)
    with open(_path, 'w', encoding='utf-8') as _csv:
        chunk = file.read(file_chunk_size)
        while chunk:
            _csv.write(chunk)
            chunk = file.read(file_chunk_size)
    Slurp(_path)
    return f"Slurped {_name}"


def slurp_excel(file, filename):
    _name = secure_filename(filename).rsplit('.', 1)[0]
    with xlrd.open_workbook(file_contents=file.read()) as workbook:
        sheet_num = 0
        for sheet in workbook.sheets():
            _name_sheet = _name + f'_sheet_{sheet_num}.csv'
            _path = path.join(csv_dir, _name_sheet)
            with open(_path, 'w', encoding='utf-8') as _file:
                _writer = csv.writer(_file, quoting=csv.QUOTE_ALL)
                for row in sheet.get_rows():
                    _writer.writerow(cell.value for cell in row)
            Slurp(_path)
            yield f"Slurped {_name}"
            sheet_num += 1


def slurp_zip(zip_file: zipfile.ZipFile, type_: str):
    for item in zip_file.namelist():
        with zip_file.open(item) as file:
            if type_ == 'zip-csv':
                yield slurp_csv(file, item)
            elif type_ == 'zip-excel':
                yield from slurp_excel(file, item)
            else:
                yield 'Not sure how you got here'
