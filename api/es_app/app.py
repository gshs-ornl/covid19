from os import path

from flask import Flask, request, Response
from werkzeug.utils import secure_filename

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
        <p>Select CSV</p>
        <input type=file name=CSVFile>
        <label>
        <br><br>
        <input type=checkbox name=testmode>Enable test mode
        </label>
        <br><br>
        <input type=submit value=Upload>
    </form>
    <h2>Once submitted, do not close the browser window!</h2>
    <p>You will be see a message upon completion</p>
    </html>
 
"""


@app.route('/', methods=['GET', 'POST'])
def landing():
    if not request.method == 'POST':
        return landing_html
    upload = request.files.get('CSVFile')
    if upload is None:
        raise FileNotFoundError
    file_name = secure_filename(upload.filename)
    local_save = path.join(csv_dir, file_name)
    upload.save(local_save)
    if request.form.get('testmode'):
        with open(local_save, encoding='utf-8') as f_test:
            contents = f_test.read()
        return {
            'saved_file': local_save,
            'upload_contents': upload.read().decode('utf-8'),
            'saved_contents': contents
        }
    Slurp(local_save)
    return "File slurped"


@app.route('/pipe', methods=['GET'])
def run_pipe():
    limit = request.args.get('limit', 0, int)
    from_ = request.args.get('from', '')
    to = request.args.get('to', '')
    chunk = request.args.get('chunk', 10, int)
    tmp = Pipe(limit=limit, from_='', to='')
    # Currently omitting from_ and to until psql function updated

    def yield_shell():
        yield f'Beginning requst: {pretty_time()}\n'
        yield from tmp.flow(chunk_size=chunk)
        yield f'Request complete: {pretty_time()}\n'
        yield f'Documents uploaded: {tmp.transfer_count}\n'

    # start_time = pretty_time()
    # tmp.flow(chunk_size=chunk)
    # end_time = pretty_time()
    # return {
    #     'start_time': start_time,
    #     'end_time': end_time,
    #     'records_processed': tmp.transfer_count
    # }
    return Response(yield_shell(), mimetype='text/plain')


if __name__ == '__main__':
    app.run(port=8888)
