#!/usr/bin/env python
"""
Flask app file.

"""
from flask import Flask, abort, jsonify, request, redirect, render_template, url_for
from utils import json_or_template, validate_post
import config
import bbs


app = Flask(__name__, template_folder='../templates', static_folder='../static')
app.config['MAX_CONTENT_LENGTH'] = config.MAX_CONTENT_LENGTH
r = config.get_redis()

if config.SENTRY_DSN:
    from raven.contrib.flask import Sentry
    sentry = Sentry(app, dsn=config.SENTRY_DSN)


@app.context_processor
def app_context():
    return {
        'SITE_URL': config.SITE_URL,
        'SUBJECT_MAXLEN': config.SUBJECT_MAXLEN,
        'MAX_REPLIES': config.MAX_REPLIES,
        'MAX_PAGES': config.MAX_PAGES,
        'BOARDS': config.BOARDS,
        'DEBUG': app.debug,
    }


@app.template_filter()
def pluralize(value, singular, plural):
    if value == 1:
        return singular
    return plural


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
    if request.is_xhr:
        return jsonify(ctx)
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
        subject, data = validate_post(request, config.BOARDS[board_id], r=r, with_subject=True)
        thread_id = bbs.new_thread(r, request, board_id, subject, data)
        return redirect(url_for('thread', board_id=board_id, thread_id=thread_id))

    threads = bbs.get_threads(r, board_id, page - 1)
    return {
        'page': page,
        'replies': threads,
        'board': config.BOARDS[board_id],
    }


@app.route('/<board_id>/thread/<int:thread_id>', methods=['GET', 'POST'])
@json_or_template()
def thread(board_id, thread_id):
    if request.method == 'POST':
        try:
            data = validate_post(request, config.BOARDS[board_id], r=r)
            reply_id = bbs.new_reply(r, request, board_id, thread_id, data)
            thread_url = url_for('thread', board_id=board_id, thread_id=thread_id)
            return redirect('%s#id%d' % (thread_url, reply_id))
        except bbs.ReplyLimitError:
            abort(400, 'Thread reply limit reached.')

    try:
        start = int(request.args.get('start', 0))
    except:
        start = 0

    replies = bbs.get_replies(r, board_id, thread_id, start)

    if not replies:
        if not bbs.thread_exists(r, board_id, thread_id):
            if thread_id > bbs.count(r, board_id):
                abort(404)
            abort(410)

    return {
        'thread_id': thread_id,
        'thread_subject': bbs.get_subject(r, board_id, thread_id),
        'thread_replies': bbs.get_reply_count(r, board_id, thread_id),
        'replies': replies,
        'board': config.BOARDS[board_id],
    }


if __name__ == '__main__':
    from flask import send_from_directory

    @app.route(config.UPLOAD_URL + '<path:filename>')
    def uploaded_file(filename):
        return send_from_directory(config.UPLOAD_ROOT, filename)

    assert r.ping()
    app.debug = True
    app.run(port=8000)
