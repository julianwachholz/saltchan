import os
from collections import OrderedDict


# ----
# Content and behaviour settings
#
BOARDS = OrderedDict([
    ('a', {
        'id': 'a',
        'title': 'About pgpchan',
        'subtitle': 'General discussion around pgpchan',
        'description': '/a/ - About pgpchan - Meta discussion around pgpchan etcetera.',
    }),
    ('b', {
        'id': 'b',
        'title': 'Random',
        'subtitle': 'Well what did you expect?',
        'description': '/b/ - Random - Miscellaneous discussion about no particular topic.',
    }),
    ('c', {
        'id': 'c',
        'title': 'Clowns',
        'subtitle': 'Don\'t trust people wearing facepaint.',
        'description': '/c/ - Clowns - We cannot explain your disproportionate fear of clowns.',
    }),
])

SUBJECT_MAXLEN = 200

MAX_PAGES = 10
THREADS_PER_PAGE = 10


# ----
# Application settings
#
REDIS_HOST = os.environ.get('REDIS_HOST', 'localhost')
REDIS_PORT = os.environ.get('REDIS_PORT', 6379)
REDIS_DB = os.environ.get('REDIS_DB', 0)


def get_redis():
    from redis import StrictRedis
    return StrictRedis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB)

RECAPTCHA = bool(os.environ.get('RECAPTCHA', False))
RECAPTCHA_KEY = None
RECAPTCHA_SECRET = None

if RECAPTCHA:
    RECAPTCHA_KEY = os.environ.get('RECAPTCHA_KEY')
    RECAPTCHA_SECRET = os.environ.get('RECAPTCHA_SECRET')

SENTRY_DSN = os.environ.get('SENTRY_DSN', False)

ERRORS = {
    'nacl': "The TweetNacl library failed to load. Fix this by running bower install.",
    '429': "You are submitting posts too quickly, cool down for a minute.",
}
