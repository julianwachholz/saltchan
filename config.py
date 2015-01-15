import os
from collections import OrderedDict


# ----
# Content and behaviour settings
#
BOARDS = OrderedDict([
    ('b', {
        'id': 'b',
        'title': 'Random',
    }),
])

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
