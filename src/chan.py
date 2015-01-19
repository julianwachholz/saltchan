#!/usr/bin/env python
"""
Flask app file.

"""
from flask import Flask, abort, jsonify, request, redirect, render_template, url_for
from utils import json_or_template, validate_post
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
        'SUBJECT_MAXLEN': config.SUBJECT_MAXLEN,
        'MAX_REPLIES': config.MAX_REPLIES,
        'MAX_PAGES': config.MAX_PAGES,
        'BOARDS': config.BOARDS,
        'RECAPTCHA': config.RECAPTCHA,
        'RECAPTCHA_KEY': config.RECAPTCHA_KEY,
        'DEBUG': app.debug,
    }


@app.route('/')
def index():
    return render_template('index.html')


@app.errorhandler(400)
@app.errorhandler(404)
@app.errorhandler(410)
@app.route('/error/')
@app.route('/error/<error>/')
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


@app.route('/<board_id>/', methods=['GET', 'POST'])
@app.route('/<board_id>/<int:page>/', methods=['GET', 'POST'])
@json_or_template()
def board(board_id, page=1):
    if board_id not in config.BOARDS.keys() or page > config.MAX_PAGES:
        abort(404)

    if page < 1:
        return redirect(url_for('board', board_id=board_id))

    if request.method == 'POST':
        subject, data = validate_post(request, True)
        thread_id = bbs.new_thread(r, request, board_id, subject, data)
        return redirect(url_for('thread', board_id=board_id, thread_id=thread_id))

    threads = bbs.get_threads(r, board_id, page - 1)
    return {
        'page': page,
        'threads': threads,
        'board': config.BOARDS[board_id],
    }


@app.route('/<board_id>/thread/<int:thread_id>', methods=['GET', 'POST'])
@json_or_template()
def thread(board_id, thread_id):
    if request.method == 'POST':
        try:
            data = validate_post(request)
            reply_id = bbs.new_reply(r, request, board_id, thread_id, data)
            thread_url = url_for('thread', board_id=board_id, thread_id=thread_id)
            return redirect('%s#id%d' % (thread_url, reply_id))
        except bbs.ReplyLimitError:
            abort(400, 'Thread reply limit reached.')

    posts = bbs.get_posts(r, board_id, thread_id)
    if not posts:
        if thread_id > bbs.count(r, board_id):
            abort(404)
        abort(410)

    return {
        'thread_id': thread_id,
        'thread_subject': bbs.get_subject(r, board_id, thread_id),
        'thread_replies': bbs.get_reply_count(r, board_id, thread_id),
        'posts': posts,
        'board': config.BOARDS[board_id],
    }


if __name__ == '__main__':
    assert r.ping()
    app.debug = True
    app.run(port=8000)
