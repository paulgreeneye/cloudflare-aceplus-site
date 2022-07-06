from flask import Flask, render_template, request, redirect, jsonify
import json as json

app = Flask(__name__)


@app.route('/', methods=['GET'])
def index_page():
    keys = dict(request.headers).keys()
    values = dict(request.headers).values()
    return render_template('index.html', headers=zip(keys, values))


@app.route('/admin', methods=['GET'])
def admin_page():
    keys = dict(request.headers).keys()
    values = dict(request.headers).values()
    return render_template('admin.html', headers=zip(keys, values))


@app.route('/view_image', methods=['GET'])
def image_page():
    return render_template('view_image.html')


if __name__ == "__main__":
    app.run(host="0.0.0.0") # debug=True, host="0.0.0.0", ssl_context='adhoc'
