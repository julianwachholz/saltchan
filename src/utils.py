import json
import requests
from functools import wraps
from flask import abort, request, render_template
import config


def json_or_template(template=None):
    """
    Returns a templated response or JSON
    if request used an XMLHttpRequest.

    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            template_name = template
            if template_name is None:
                template_name = request.endpoint \
                    .replace('.', '/') + '.html'
            ctx = f(*args, **kwargs)
            if ctx is None:
                ctx = {}
            elif not isinstance(ctx, dict):
                return ctx
            return render_template(template_name, **ctx)
        return decorated_function
    return decorator


def validate_post(request, with_subject=False):
    """
    Check if we actually got a text input and verify the captcha.

    """
    data = request.form.get('data', '')
    try:
        obj = json.loads(data)
    except ValueError:
        if sentry:
            sentry.captureException()
        abort(400, 'Invalid JSON received.')

    if not obj['text'].strip():
        abort(400, 'Empty message.')

    if with_subject:
        subject = request.form.get('subject', '').strip()

        if len(subject) > config.SUBJECT_MAXLEN:
            abort(400, 'Subject is too long.')

    if config.RECAPTCHA:
        params = {
            'secret': config.RECAPTCHA_SECRET,
            'response': request.form.get('g-recaptcha-response'),
            'remoteip': request.remote_addr,
        }
        url = 'https://www.google.com/recaptcha/api/siteverify?'
        url += '&'.join('{}={}'.format(key, val) for key, val in params.items())
        r = requests.get(url)
        if not r.json()['success']:
            abort(400, 'ReCAPTCHA challenge failed.')

    if with_subject:
        return subject, data
    return data
