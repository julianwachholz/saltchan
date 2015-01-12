import dateutil.parser
from datetime import datetime
import config

KEY_COUNT = 'count_%(board)s'
KEY_POST = 'post_%(board)s_%(id)d'
KEY_BUMP = 'bump_%(board)s_%(thread)s'
KEY_BOARD = 'board_%(board)s'
KEY_REPLIES = 'thread_%(board)s_%(thread)d'
KEY_REPLY_COUNT = 'replies_%(board)s_%(thread)d'


def new_thread(r, board, text):
    thread = r.incr(KEY_COUNT % {'board': board})
    now = datetime.utcnow()
    pipe = r.pipeline()
    pipe.hmset(KEY_POST % {'board': board, 'id': thread}, {'id': thread, 'date': str(now), 'text': text})
    pipe.set(KEY_BUMP % {'board': board, 'thread': str(thread)}, now.strftime('%s'))
    pipe.incr(KEY_REPLY_COUNT % {'board': board, 'thread': thread})
    pipe.lpush(KEY_BOARD % {'board': board}, thread)
    pipe.rpush(KEY_REPLIES % {'board': board, 'thread': thread}, thread)
    pipe.execute()
    return thread


get = lambda board, field: 'post_%s_*->%s' % (board, field)


def _cast_post(post):
    replies = int(post[3]) if len(post) == 4 else None
    return {
        'id': int(post[0]),
        'date': dateutil.parser.parse(post[1].decode('utf-8')),
        'text': post[2].decode('utf-8'),
        'reply_count': replies,
    }


def get_threads(r, board, page=0):
    threads = r.sort(
        KEY_BOARD % {'board': board},
        num=config.THREADS_PER_PAGE,
        start=config.THREADS_PER_PAGE * page,
        by=KEY_BUMP % {'board': board, 'thread': '*'},
        get=[get(board, 'id'), get(board, 'date'), get(board, 'text'), 'replies_%s_*' % board],
        desc=True,
        groups=True
    )
    return map(_cast_post, threads)


def get_posts(r, board, thread_id):
    posts = r.sort(
        KEY_REPLIES % {'board': board, 'thread': thread_id},
        by='nosort',
        get=[get(board, 'id'), get(board, 'date'), get(board, 'text')],
        groups=True
    )
    return map(_cast_post, posts)


def new_reply(r, board, thread_id, text):
    post = r.incr(KEY_COUNT % {'board': board})
    now = datetime.utcnow()
    pipe = r.pipeline()
    pipe.hmset(KEY_POST % {'board': board, 'id': post}, {'id': post, 'date': str(now), 'text': text})
    pipe.set(KEY_BUMP % {'board': board, 'thread': str(thread_id)}, now.strftime('%s'))
    pipe.incr(KEY_REPLY_COUNT % {'board': board, 'thread': thread_id})
    pipe.rpush(KEY_REPLIES % {'board': board, 'thread': thread_id}, post)
    pipe.execute()
    return post
