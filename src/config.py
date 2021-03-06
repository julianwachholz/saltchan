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
        'description': 'Meta discussion about everything related to saltchan etcetera.',
        'allow_uploads': False,
        'bump_limit': 50,
    }),
    ('b', {
        'id': 'b',
        'title': 'Random',
        'subtitle': 'Well what did you expect?',
        'description': 'Miscellaneous discussion about no particular topic.',
        'allow_uploads': True,
        'bump_limit': 25,
    }),
    ('g', {
        'id': 'g',
        'title': 'Technology',
        'subtitle': None,
        'description': 'People come here and discuss various advancements in technology.',
        'allow_uploads': True,
        'bump_limit': 50,
    })
])

SUBJECT_MAXLEN = 200

MAX_PAGES = 10
THREADS_PER_PAGE = 10
MAX_REPLIES = 150

DATE_FORMAT = '%Y-%m-%dT%H:%M:%SZ'

# file uploads
MAX_CONTENT_LENGTH = 5 * 1024 * 1024  # 5 MB
MIME_READ = 128  # How many bytes to read from a file to guess its MIME
ALLOWED_MIME = [
    'image/jpeg',
    'image/gif',
    'image/png',
]


# ----
# Application settings
#
APP_PATH = os.path.dirname(os.path.dirname(__file__))


REDIS_HOST = os.environ.get('REDIS_HOST', 'localhost')
REDIS_PORT = os.environ.get('REDIS_PORT', 6379)
REDIS_DB = os.environ.get('REDIS_DB', 0)

UPLOAD_ROOT = os.environ.get('UPLOAD_FOLDER', os.path.join(APP_PATH, 'files'))
UPLOAD_URL = '/files/'

GA_ID = os.environ.get('GA_ID', None)


def get_redis():
    from redis import StrictRedis
    return StrictRedis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB)

SENTRY_DSN = os.environ.get('SENTRY_DSN', False)

ERRORS = {
    '413': "Your request was too large. Try a smaller file or less recipients for an encrypted message.",
    '429': "You are submitting posts too quickly, cool down for a minute.",
}
