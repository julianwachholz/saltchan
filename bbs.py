import json
import dateutil.parser
from datetime import datetime
import config

KEY_COUNT = 'count_%(board)s'
KEY_POST = 'post_%(board)s_%(id)d'
KEY_BUMP = 'bump_%(board)s_%(thread)d'
KEY_BUMP_SORT = 'bump_%(board)s_*->time'
KEY_BOARD = 'board_%(board)s'
KEY_REPLIES = 'thread_%(board)s_%(thread)d'
KEY_REPLY_COUNT = 'replies_%(board)s_%(thread)d'


def new_thread(r, request, board_id, subject, data):
    thread = r.incr(KEY_COUNT % {'board': board_id})
    now = datetime.utcnow()
    pipe = r.pipeline()
    pipe.hmset(KEY_POST % {'board': board_id, 'id': thread}, {
        'id': thread,
        'date': str(now),
        'data': data,
        'subject': subject,
    })
    pipe.hmset(KEY_BUMP % {'board': board_id, 'thread': thread}, {
        'time': now.strftime('%s'),
        'ip': request.remote_addr,
    })
    pipe.incr(KEY_REPLY_COUNT % {'board': board_id, 'thread': thread})
    pipe.lpush(KEY_BOARD % {'board': board_id}, thread)
    pipe.rpush(KEY_REPLIES % {'board': board_id, 'thread': thread}, thread)
    pipe.execute()
    return thread


get = lambda board, field: 'post_%s_*->%s' % (board, field)


def _cast_post(post):
    postobj = {
        'id': int(post[0]),
        'date': dateutil.parser.parse(post[1].decode('utf-8')),
        'data': json.loads(post[2].decode('utf-8')),
    }
    if len(post) == 5:
        postobj.update({
            'subject': post[3].decode('utf-8'),
            'reply_count': int(post[4]),
        })
    return postobj


def get_threads(r, board, page=0):
    threads = r.sort(
        KEY_BOARD % {'board': board},
        num=config.THREADS_PER_PAGE,
        start=config.THREADS_PER_PAGE * page,
        by=KEY_BUMP_SORT % {'board': board},
        get=[get(board, 'id'), get(board, 'date'), get(board, 'data'), get(board, 'subject'), 'replies_%s_*' % board],
        desc=True,
        groups=True
    )
    return map(_cast_post, threads)


def purge_thread(r, board):
    """
    Purge the oldest thread beyond the bump limit.

    """
    threads_key = KEY_BOARD % {'board': board}
    llen = r.llen(threads_key)
    if not llen > config.THREADS_PER_PAGE * config.MAX_PAGES:
        return
    thread_id = r.rpop(threads_key)
    return thread_id


def get_posts(r, board, thread_id):
    posts = r.sort(
        KEY_REPLIES % {'board': board, 'thread': thread_id},
        by='nosort',
        get=[get(board, 'id'), get(board, 'date'), get(board, 'data')],
        groups=True
    )
    if not posts:
        return False
    return map(_cast_post, posts)


def get_subject(r, board_id, thread_id):
    return r.hget(KEY_POST % {'board': board_id, 'id': thread_id}, 'subject').decode('utf-8')


def new_reply(r, request, board_id, thread_id, data):
    post = r.incr(KEY_COUNT % {'board': board_id})
    now = datetime.utcnow()
    pipe = r.pipeline()
    pipe.hmset(KEY_POST % {'board': board_id, 'id': post}, {'id': post, 'date': str(now), 'data': data})

    bump_key = KEY_BUMP % {'board': board_id, 'thread': thread_id}
    last_bump_ip = r.hget(bump_key, 'ip').decode('utf-8')
    if last_bump_ip != request.remote_addr:
        pipe.hmset(KEY_BUMP % {'board': board_id, 'thread': thread_id}, {
            'time': now.strftime('%s'),
            'ip': request.remote_addr,
        })

    pipe.incr(KEY_REPLY_COUNT % {'board': board_id, 'thread': thread_id})
    pipe.rpush(KEY_REPLIES % {'board': board_id, 'thread': thread_id}, post)
    pipe.execute()
    return post
