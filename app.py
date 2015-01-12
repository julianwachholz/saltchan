import re
import requests
from flask import Flask, abort, request, redirect, render_template, url_for
from jinja2 import evalcontextfilter, Markup, escape
from redis import StrictRedis
from utils import templated
import config
import bbs

app = Flask(__name__)
r = StrictRedis(host='localhost', port=6379, db=1)

_RE_PARA = re.compile(r'(?:\r\n|\n){2,}')


@app.context_processor
def inject_user():
    return {
        'RECAPTCHA': config.RECAPTCHA,
        'RECAPTCHA_KEY': config.RECAPTCHA_KEY,
    }


@app.template_filter()
@evalcontextfilter
def nl2br(eval_ctx, value):
    result = u'\n\n'.join(u'<p>%s</p>' % p.replace('\n', '<br>\n')
                          for p in _RE_PARA.split(escape(value)))
    if eval_ctx.autoescape:
        result = Markup(result)
    return result


def _validate_form(request):
    """
    Check if we actually got a text input and verify the captcha.

    """
    text = request.form.get('text', '').strip()
    if not text:
        abort(400)

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
            abort(400)

    return text


@app.route('/')
@templated('index.html')
def index():
    return {
        'boards': config.BOARDS,
    }


@app.route('/<board_id>/', methods=['GET', 'POST'])
@app.route('/<board_id>/<int:page>/', methods=['GET', 'POST'])
@templated('board.html')
def board(board_id, page=1):
    if board_id not in config.BOARDS.keys() or page > 10:
        return '404', 404

    if request.method == 'POST':
        text = _validate_form(request)
        thread_id = bbs.new_thread(r, request, board_id, text)
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
        text = _validate_form(request)
        reply_id = bbs.new_reply(r, request, board_id, thread_id, text)
        thread_url = url_for('thread', board_id=board_id, thread_id=thread_id)
        return redirect('%s#id%d' % (thread_url, reply_id))

    posts = bbs.get_posts(r, board_id, thread_id)
    return {
        'thread_id': thread_id,
        'posts': posts,
        'board': config.BOARDS[board_id],
    }


if __name__ == '__main__':
    assert r.ping()
    app.debug = True
    app.run(port=8000)
