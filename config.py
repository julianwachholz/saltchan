import os
from collections import OrderedDict


BOARDS = OrderedDict([
    ('b', {
        'id': 'b',
        'title': 'Random',
    }),
    ('r9k', {
        'id': 'r9k',
        'title': 'Robot 9000',
    }),
])

MAX_PAGES = 3
THREADS_PER_PAGE = 3


RECAPTCHA = bool(os.environ.get('RECAPTCHA', False))
RECAPTCHA_KEY = None
RECAPTCHA_SECRET = None

if RECAPTCHA:
    RECAPTCHA_KEY = os.environ.get('RECAPTCHA_KEY')
    RECAPTCHA_SECRET = os.environ.get('RECAPTCHA_SECRET')

ERRORS = {
    'nacl': "The TweetNacl library failed to load. Fix this by running bower install.",
}
