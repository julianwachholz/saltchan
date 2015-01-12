import os


BOARDS = [
    'b',
    'r9k',
]

BOARD_INFO = {
    'b': {
        'id': 'b',
        'title': 'Random',
    },
    'r9k': {
        'id': 'r9k',
        'title': 'Robot 9000',
    },
}

THREADS_PER_PAGE = 10


RECAPTCHA = bool(os.environ.get('RECAPTCHA', True))

if RECAPTCHA:
    RECAPTCHA_KEY = os.environ.get('RECAPTCHA_KEY')
    RECAPTCHA_SECRET = os.environ.get('RECAPTCHA_SECRET')
