from concurrent.futures import ThreadPoolExecutor, Future
import zipfile

from flask import Flask, request, Response

from es_app.common import get_var, pretty_time
from es_app.parse import ElasticParse
from es_app.pipe import Pipe
from es_app.slurp_forms import slurp_html, slurp_csv, slurp_excel, slurp_zip


flask_app_name = get_var('FLASK_APP_NAME', 'es_app')
flask_debug = get_var('FLASK_DEBUG', True)

executor = ThreadPoolExecutor(4)
current_task: Future = Future()
pipe_obj = Pipe()

app = Flask(flask_app_name, static_url_path='')


@app.route('/es/put/<uid>', methods=['POST', 'PUT'])
def process_input(uid):
    """Accepts posted json for upload to covid19 elasticsearch
    Endpoint non-operational due to schema changes
    Use functionality provided by pipe instead for db to db

    :param uid: id value to mark process
    :return: dictionary with id, start, end time
    """
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
    """Test endpoint meant to demonstrate conversions
    by process_input

    :param uid: id value to mark the process
    :return: dictionary with id, start, end, and data converted
    """
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
    """Notes /es/ endpoints

    :return: help text for /es/ endpoints
    """
    return 'Use /put/<uid> to do things and /test-put/<uid> to test things'


@app.route('/', methods=['GET', 'POST'])
def landing():
    """Loads page for accepting uploaded data for slurping

    :return: completion message
    """
    if not request.method == 'POST':
        return slurp_html
    file_type = request.form.get('mode')
    upload = request.files.get('CSVFile')
    if upload is None:
        return "File not found. Did you upload one?"
    if file_type in ['zip-csv', 'zip-excel']:
        if not zipfile.is_zipfile(upload):
            return Response('Unsupported archive', status=415)
        with zipfile.ZipFile(upload) as z_upload:
            return Response(slurp_zip(z_upload, file_type))
    if file_type == 'excel':
        return Response(slurp_excel(upload, upload.filename))
    if file_type == 'csv':
        return slurp_csv(upload, upload.filename)


@app.route('/hack-pipe', methods=['GET'])
def run_pipe():
    """Deprecated pipe that used some hacky methods to work
    for db to db transfer

    :return: progress and task completion text
    """
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
    """Creates db to db pipe process in a separate thread

    :return: Pipe scheduling success or failure message
    """
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
    """Checks if there is a pipe task currently running and reports
    information on its progress and completion state

    :return: progress text or completion information
    """
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
    app.run(port=9090)
