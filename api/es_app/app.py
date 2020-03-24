from flask import Flask, request

from es_app.common import get_var, pretty_time
from es_app.parse import ElasticParse


flask_app_name = get_var('FLASK_APP_NAME', 'es_app')
flask_debug = get_var('FLASK_DEBUG', True)

app = Flask(flask_app_name, static_url_path='')


@app.route('/put/<uid>', methods=['POST', 'PUT'])
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


@app.route('/test-put/<uid>', methods=['POST', 'PUT'])
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


if __name__ == '__main__':
    app.run(port=8888)
