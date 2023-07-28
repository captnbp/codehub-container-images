# code-hub-nginx

Docker image for extra container in code-server pod.

This will allow to rewrite incoming URIs from JupyterHub's proxy ('/user/foo/') to '/' as code-server doesn't manage base path properly.
