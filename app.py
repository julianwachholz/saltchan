import re
import requests
from flask import Flask, request, redirect, render_template, url_for
from jinja2 import evalcontextfilter, Markup, escape
from redis import StrictRedis
import config
import bbs

app = Flask(__name__)
r = StrictRedis(host='localhost', port=6379, db=1)

_RE_PARA = re.compile(r'(?:\r\n|\n){2,}')


@app.context_processor
def inject_user():
    return {
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


def _check_recaptcha(request):
    params = {
        'secret': config.RECAPTCHA_SECRET,
        'response': request.form.get('g-recaptcha-response'),
        'remoteip': request.remote_addr,
    }
    url = 'https://www.google.com/recaptcha/api/siteverify?'
    url += '&'.join('{}={}'.format(key, val) for key, val in params.items())
    r = requests.get(url)
    return r.status_code == 200 and r.json()['success']


@app.route('/')
def index():
    return render_template('index.html',
                           boards=config.BOARDS,
                           board_info=config.BOARD_INFO)


@app.route('/<board>/', methods=['GET', 'POST'])
@app.route('/<board>/<int:page>/')
def board(board, page=1):
    if board not in config.BOARDS or page > 10:
        return '404', 404

    if request.method == 'POST':
        if not _check_recaptcha(request):
            return 'Failed CAPTCHA.', 400
        thread_id = bbs.new_thread(r, board, request.form.get('text'))
        return redirect(url_for('thread', board=board, thread_id=thread_id))

    threads = bbs.get_threads(r, board, page - 1)
    return render_template('board.html',
                           page=page,
                           threads=threads,
                           board=config.BOARD_INFO[board])


@app.route('/<board>/thread/<int:thread_id>', methods=['GET', 'POST'])
def thread(board, thread_id):
    if request.method == 'POST':
        if not _check_recaptcha(request):
            return 'Failed CAPTCHA.', 400
        reply_id = bbs.new_reply(r, board, thread_id, request.form.get('text'))
        thread_url = url_for('thread', board=board, thread_id=thread_id)
        return redirect('%s#id%d' % (thread_url, reply_id))

    posts = bbs.get_posts(r, board, thread_id)
    return render_template('thread.html',
                           thread_id=thread_id,
                           posts=posts,
                           board=config.BOARD_INFO[board])


if __name__ == '__main__':
    assert r.ping()
    app.debug = True
    app.run(port=8000)
