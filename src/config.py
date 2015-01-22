import os
from collections import OrderedDict


# ----
# Content and behaviour settings
#
SITE_URL = 'https://saltchan.org'

BOARDS = OrderedDict([
    ('a', {
        'id': 'a',
        'title': 'About saltchan',
        'subtitle': 'General discussion around saltchan',
        'description': '/a/ - About saltchan - Meta discussion around saltchan etcetera.',
        'bump_limit': 50,
    }),
    ('b', {
        'id': 'b',
        'title': 'Random',
        'subtitle': 'Well what did you expect?',
        'description': '/b/ - Random - Miscellaneous discussion about no particular topic.',
        'bump_limit': 25,
    }),
])

SUBJECT_MAXLEN = 200

MAX_PAGES = 10
THREADS_PER_PAGE = 10
MAX_REPLIES = 250

DATE_FORMAT = '%Y-%m-%d %H:%M:%S'


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
    '413': "Your request was too large. Try a smaller file or less recipients for an encrypted message.",
    '429': "You are submitting posts too quickly, cool down for a minute.",
    'nacl': "The TweetNacl library failed to load. Fix this by running bower install.",
}
