#!/usr/bin/env python
"""
PGPchan app file.

"""
import json
import requests
from flask import Flask, abort, request, redirect, render_template, url_for
from utils import templated
import config
import bbs

app = Flask(__name__)
r = config.get_redis()

if config.SENTRY_DSN:
    from raven.contrib.flask import Sentry
    sentry = Sentry(app, dsn=config.SENTRY_DSN)
else:
    sentry = None


@app.context_processor
def app_context():
    return {
        'MAX_PAGES': config.MAX_PAGES,
        'BOARDS': config.BOARDS,
        'RECAPTCHA': config.RECAPTCHA,
        'RECAPTCHA_KEY': config.RECAPTCHA_KEY,
    }


@app.errorhandler(400)
@app.errorhandler(404)
@app.errorhandler(410)
@app.route('/error/')
@app.route('/error/<error>/')
@templated('error.html')
def error(error=None):
    if hasattr(error, 'description'):
        code = error.code
        ctx = {
            'error': error.description,
            'is_redirect': False,
        }
    else:
        code = 400
        ctx = {
            'error': config.ERRORS.get(error, 'Unknown error.'),
            'is_redirect': True,
        }
    return render_template('error.html', **ctx), code


def _validate_form(request, with_subject=False):
    """
    Check if we actually got a text input and verify the captcha.

    """
    data = request.form.get('data', '')
    try:
        obj = json.loads(data)
    except ValueError:
        if sentry:
            sentry.captureException()
        abort(400, 'Invalid JSON received.')

    if not obj['message'].strip():
        abort(400, 'Empty message.')

    if with_subject:
        subject = request.form.get('subject', '').strip()

    if config.RECAPTCHA:
        params = {
            'secret': config.RECAPTCHA_SECRET,
            'response': request.form.get('g-recaptcha-response'),
            'remoteip': request.remote_addr,
        }
        url = 'https://www.google.com/recaptcha/api/siteverify?'
        url += '&'.join('{}={}'.format(key, val) for key, val in params.items())
        r = requests.get(url)
        if not r.json()['success']:
            abort(400, 'ReCAPTCHA challenge failed.')

    if with_subject:
        return subject, data
    return data


@app.route('/')
@templated('index.html')
def index():
    pass


@app.route('/<board_id>/', methods=['GET', 'POST'])
@app.route('/<board_id>/<int:page>/', methods=['GET', 'POST'])
@templated('board.html')
def board(board_id, page=1):
    if board_id not in config.BOARDS.keys() or page > config.MAX_PAGES:
        abort(404)

    if page < 1:
        return redirect(url_for('board', board_id=board_id))

    if request.method == 'POST':
        subject, data = _validate_form(request, True)
        thread_id = bbs.new_thread(r, request, board_id, subject, data)
        return redirect(url_for('thread', board_id=board_id, thread_id=thread_id))

    threads = bbs.get_threads(r, board_id, page - 1)
    return {
        'page': page,
        'threads': threads,
        'board': config.BOARDS[board_id],
    }


@app.route('/<board_id>/thread/<int:thread_id>', methods=['GET', 'POST'])
@templated('thread.html')
def thread(board_id, thread_id):
    if request.method == 'POST':
        data = _validate_form(request)
        reply_id = bbs.new_reply(r, request, board_id, thread_id, data)
        thread_url = url_for('thread', board_id=board_id, thread_id=thread_id)
        return redirect('%s#id%d' % (thread_url, reply_id))

    posts = bbs.get_posts(r, board_id, thread_id)
    if not posts:
        if thread_id > bbs.count(r, board_id):
            abort(404)
        abort(410)

    return {
        'thread_id': thread_id,
        'thread_subject': bbs.get_subject(r, board_id, thread_id),
        'posts': posts,
        'board': config.BOARDS[board_id],
    }


if __name__ == '__main__':
    assert r.ping()
    app.debug = True
    app.run(port=8000)
