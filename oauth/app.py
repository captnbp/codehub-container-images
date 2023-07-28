#!/usr/bin/env python3
"""
whoami service authentication with the Hub
"""

from functools import wraps
import json
import os
from urllib.parse import urlparse
import datetime
#import pdb
from flask import Flask, redirect, request, Response, make_response

from jupyterhub.services.auth import HubOAuth


prefix = os.environ.get('JUPYTERHUB_SERVICE_PREFIX', '/')
prefix = '/'

auth = HubOAuth(
    api_token=os.environ['JUPYTERHUB_API_TOKEN'],
    cache_max_age=60,
)

app = Flask(__name__)

@app.route(prefix + 'validate')
def whoami():
    #pdb.set_trace()
    original_uri = request.headers['X-Original-URI']
    app.logger.debug("X-Original-URI = %s" % original_uri)
    path = urlparse(original_uri).path
    if path[len(path) - 1] == '/':
      path = path[0:len(path)-1]
    #if it's oauth_callback, allow it:
    if os.path.split(path)[1] == 'oauth_callback':
      return ('', 200)
    token = request.cookies.get(auth.cookie_name)
    if token:
        user = auth.user_for_token(token)
    else:
        user = None
    if user:
        if user['name'] == os.environ['JUPYTERHUB_USER']:
            #return f(user, *args, **kwargs)
            return ('', 200)
        else:
            return ('', 403)
    else:
        # redirect to login url on failed auth
        state = auth.generate_state(next_url=original_uri)
        #response = make_response(redirect(auth.login_url + '&state=%s' % state))
        #response.set_cookie(auth.state_cookie_name, state)
        return ('', 401, {'X-Auth-Login-Url': auth.login_url + '&state=%s' % state, 'X-Auth-State': state })


@app.route(prefix + 'oauth_callback')
def oauth_callback():
    #pdb.set_trace()
    code = request.args.get('code', None)
    if code is None:
        return ('', 403)

    # validate state field
    arg_state = request.args.get('state', None)
    cookie_state = request.cookies.get(auth.state_cookie_name)
      #cookie_state = request.headers['X-Auth-State']
    if arg_state is None or arg_state != cookie_state:
        # state doesn't match
        return ('', 403)

    token = auth.token_for_code(code)
    next_url = auth.get_next_url(cookie_state) or prefix
    app.logger.debug("next_url = %s" % next_url)
    if next_url.startswith("https,http"):
        next_url = next_url.replace("https,http", "https")
    app.logger.debug("final next_url = %s" % next_url)
    response = make_response(redirect(next_url))
    response.set_cookie(auth.state_cookie_name, value="", expires=datetime.datetime.utcnow())
    #response.set_cookie(auth.cookie_name, value=token, httponly=True, secure=True, path=os.environ.get('JUPYTERHUB_SERVICE_PREFIX', '/'), expires=datetime.datetime.utcnow()+datetime.timedelta(minutes=30))
    response.set_cookie(auth.cookie_name, value=token, httponly=True, secure=True, path=os.environ.get('JUPYTERHUB_SERVICE_PREFIX', '/'))
    app.logger.debug("Response Headers = " + str(response.headers))
    return response
    
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9095, debug=True)