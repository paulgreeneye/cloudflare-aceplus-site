from flask import Flask, render_template, request, redirect, jsonify
import json as json

app = Flask(__name__)


@app.route('/', methods=['GET'])
def index_page():
    keys = dict(request.headers).keys()
    values = dict(request.headers).values()
    return render_template('index.html', headers=zip(keys, values))


if __name__ == "__main__":
    app.run(host="0.0.0.0") # debug=True, host="0.0.0.0", ssl_context='adhoc'
