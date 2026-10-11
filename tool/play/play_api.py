"""Minimal Google Play Developer API client (service-account auth).

The service account key is read from the PLAY_SERVICE_ACCOUNT_JSON
environment variable (its JSON text) or from a file given in
PLAY_SERVICE_ACCOUNT_FILE. Never commit the key.

Needs: pip install pyjwt cryptography
"""
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

PACKAGE = 'com.nwbn.blendburst'
API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' + PACKAGE
UPLOAD_API = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/' + PACKAGE
SCOPE = 'https://www.googleapis.com/auth/androidpublisher'

_token = None


def _key():
    text = os.environ.get('PLAY_SERVICE_ACCOUNT_JSON')
    if not text:
        path = os.environ.get('PLAY_SERVICE_ACCOUNT_FILE')
        if not path:
            raise SystemExit('Set PLAY_SERVICE_ACCOUNT_JSON or PLAY_SERVICE_ACCOUNT_FILE')
        text = open(path).read()
    return json.loads(text)


def token():
    global _token
    if _token and _token[1] > time.time() + 60:
        return _token[0]
    k = _key()
    now = int(time.time())
    assertion = jwt.encode(
        {'iss': k['client_email'], 'scope': SCOPE, 'aud': k['token_uri'],
         'iat': now, 'exp': now + 3600},
        k['private_key'], algorithm='RS256')
    body = urllib.parse.urlencode({
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': assertion}).encode()
    r = json.load(urllib.request.urlopen(k['token_uri'], body, timeout=60))
    _token = (r['access_token'], now + int(r['expires_in']))
    return _token[0]


class ApiError(Exception):
    pass


def call(method, url, body=None, raw=None, content_type=None, ok=(200, 204)):
    headers = {'Authorization': 'Bearer ' + token()}
    data = None
    if raw is not None:
        data = raw
        headers['Content-Type'] = content_type or 'application/octet-stream'
    elif body is not None:
        data = json.dumps(body).encode()
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=900) as r:
            text = r.read()
            return json.loads(text) if text else {}
    except urllib.error.HTTPError as e:
        text = e.read().decode(errors='replace')
        if e.code in ok:
            return {}
        raise ApiError(f'{method} {url} -> {e.code}: {text}') from None


class Edit:
    """An edit session: changes become live only on commit()."""

    def __init__(self):
        self.id = call('POST', API + '/edits', {})['id']
        self.url = f'{API}/edits/{self.id}'
        self.upload_url = f'{UPLOAD_API}/edits/{self.id}'

    def commit(self, changes_not_sent_for_review=False):
        q = '?changesNotSentForReview=true' if changes_not_sent_for_review else ''
        return call('POST', self.url + ':commit' + q)

    def abandon(self):
        call('DELETE', self.url)
