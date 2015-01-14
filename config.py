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

THREADS_PER_PAGE = 10


RECAPTCHA = bool(os.environ.get('RECAPTCHA', False))
RECAPTCHA_KEY = None
RECAPTCHA_SECRET = None

if RECAPTCHA:
    RECAPTCHA_KEY = os.environ.get('RECAPTCHA_KEY')
    RECAPTCHA_SECRET = os.environ.get('RECAPTCHA_SECRET')

SENTRY_DSN = os.environ.get('SENTRY_DSN', False)

ERRORS = {
    'nacl': "The TweetNacl library failed to load. Fix this by running bower install.",
}
