from concurrent.futures import ThreadPoolExecutor, Future
import csv
from os import path

from flask import Flask, request, Response, url_for
from werkzeug.utils import secure_filename
import xlrd

from es_app.common import get_var, pretty_time
from es_app.parse import ElasticParse
from es_app.pipe import Pipe


try:
    from cvpy.slurper import Slurp
except ModuleNotFoundError:
    def identity(x):
        return x
    Slurp = identity

flask_app_name = get_var('FLASK_APP_NAME', 'es_app')
flask_debug = get_var('FLASK_DEBUG', True)
csv_dir = get_var('CSV_DIR', '/tmp/input')
file_chunk_size = 1000

executor = ThreadPoolExecutor(4)
current_task: Future = Future()
pipe_obj = Pipe()

app = Flask(flask_app_name, static_url_path='')


@app.route('/es/put/<uid>', methods=['POST', 'PUT'])
def process_input(uid):
    start_time = pretty_time()
    content = request.get_json()
    ElasticParse(content).send_actions()
    end_time = pretty_time()
    return {
        'uid': uid,
        'start_time': start_time,
        'end_time': end_time
    }


@app.route('/es/test-put/<uid>', methods=['POST', 'PUT'])
def check_input(uid):
    start_time = pretty_time()
    content = request.get_json()
    tmp = ElasticParse(content).gen_actions()
    end_time = pretty_time()
    return {
        'uid': uid,
        'start_time': start_time,
        'end_time': end_time,
        'processed_table': tmp
    }


@app.route('/es/help')
def default():
    return 'Use /put/<uid> to do things and /test-put/<uid> to test things'


landing_html = """
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
    with open(_path, 'w', encoding='utf-8') as csv:
        chunk = file.read(file_chunk_size)
        while chunk:
            csv.write(chunk)
            chunk = file.read(file_chunk_size)
    Slurp(_path)
    return f"Slurped {_name}"


def slurp_excel(file, filename):
    _name = secure_filename(filename).rsplit('.', 1)[0]
    with xlrd.open_workbook(file_contents=file.read()) as workbook:
        for sheet in workbook.sheets():
            _name_sheet = _name + '_sheet_00.csv'
            _path = path.join(csv_dir, _name_sheet)
            with open(_path, 'w', encoding='utf-8') as _file:
                _writer = csv.writer(_file, quoting=csv.QUOTE_ALL)
                for row in sheet.get_rows():
                    _writer.writerow(row)
            Slurp(_path)
            yield f"Slurped {_name}"


@app.route('/', methods=['GET', 'POST'])
def landing():
    if not request.method == 'POST':
        return landing_html
    file_type = request.form.get('mode')
    upload = request.files.get('CSVFile')
    if upload is None:
        raise FileNotFoundError
    if file_type in ['zip-csv', 'zip-excel']:
        return "Support pending"
    if file_type == 'excel':
        return Response(slurp_excel(upload, upload.filename))
    if file_type == 'csv':
        return slurp_csv(upload, upload.filename)


@app.route('/hack-pipe', methods=['GET'])
def run_pipe():
    limit = request.args.get('limit', 0, int)
    from_ = request.args.get('from', '')
    to = request.args.get('to', '')
    chunk = request.args.get('chunk', 10, int)
    tmp = Pipe(limit=limit, from_='', to='')
    # Currently omitting from_ and to until psql function updated

    def yield_shell():
        yield f'Beginning request: {pretty_time()}\n'
        yield from tmp.yield_flow(chunk_size=chunk)
        yield f'Request complete: {pretty_time()}\n'
        yield f'Documents uploaded: {tmp.transfer_count}\n'

    return Response(yield_shell(), mimetype='text/plain')


@app.route('/schedule-pipe', methods=['GET'])
def schedule_background_pipe():
    global current_task
    global pipe_obj
    if current_task is not None and current_task.running():
        return 'Pipe in progress. Please try again later.'
    limit = request.args.get('limit', 0, int)
    from_ = request.args.get('from', '')
    to = request.args.get('to', '')
    chunk = request.args.get('chunk', 500, int)
    pipe_obj = Pipe(limit=limit, from_='', to='')
    pipe_obj.start_time = pretty_time()
    # Currently omitting from_ and to until psql function updated
    current_task = executor.submit(pipe_obj.auto_flow, chunk)
    return f'Pipe scheduled at {pipe_obj.start_time}'


@app.route('/check-pipe', methods=['GET'])
def check_background_pipe():
    global current_task
    global pipe_obj
    if current_task.running():
        return f'In progress. Current transfer count: {pipe_obj.transfer_count}'
    if current_task.cancelled():
        return {'Exception raised': current_task.exception()}
    if current_task.done():
        return {
            'message': 'Pipe complete',
            'start_time': getattr(pipe_obj, 'start_time', ''),
            'end_time': pretty_time(),
            'documents_transferred': pipe_obj.transfer_count
        }
    return 'No tasks are running or have existed'


if __name__ == '__main__':
    app.run(port=8080)
