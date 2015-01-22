import json
import requests
from functools import wraps
from werkzeug.wrappers import Response
from flask import abort, jsonify, request, render_template
from flask.json import JSONEncoder
import config


def _clean_json(obj):
    if 'board' in obj:
        obj['board_id'] = obj['board']['id']
        obj.pop('board', None)
    if 'thread_subject' in obj:
        obj.pop('thread_subject', None)
    return obj


def json_or_template(template=None):
    """
    Returns a templated response or JSON
    if request used an XMLHttpRequest.

    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            ctx = f(*args, **kwargs)

            if ctx is None:
                ctx = {}
            elif request.is_xhr and getattr(ctx, 'headers', {}).get('Location', False):
                return jsonify({
                    'location': ctx.headers['Location'],
                })
            elif not isinstance(ctx, dict):
                return ctx

            if request.is_xhr:
                return jsonify(_clean_json(ctx))

            template_name = template
            if template_name is None:
                template_name = request.endpoint \
                    .replace('.', '/') + '.html'
            return render_template(template_name, **ctx)
        return decorated_function
    return decorator


def validate_post(request, with_subject=False):
    """
    Check if we actually got a text input and verify the captcha.

    """
    if not request.is_xhr:
        abort(400, 'Invalid request.')

    data = request.form.get('data', '')
    try:
        obj = json.loads(data)
    except ValueError:
        abort(400, 'Invalid JSON received.')

    if not obj['text'].strip():
        abort(400, 'Empty message.')

    if with_subject:
        subject = request.form.get('subject', '').strip()

        if len(subject) > config.SUBJECT_MAXLEN:
            abort(400, 'Subject is too long.')

    if with_subject:
        return subject, data
    return data
