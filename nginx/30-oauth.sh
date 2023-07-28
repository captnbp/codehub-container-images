#!/usr/bin/env sh
# vim:sw=4:ts=4:et

set -e
echo "Replace Jupyter variables in nginx.conf"
sed -i -e "s/###REPLACE_WITH_THE_JUPYTERHUB_USER_ENVIRONMENT_VARIABLE###/${JUPYTERHUB_USER}/g" /etc/nginx/nginx.conf
sed -i -e "s/###REPLACE_WITH_THE_JUPYTERHUB_CLIENT_ID_ENVIRONMENT_VARIABLE###/${JUPYTERHUB_CLIENT_ID}/g" /etc/nginx/nginx.conf
