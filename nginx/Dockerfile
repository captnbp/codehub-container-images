FROM    nginxinc/nginx-unprivileged:1.25-alpine-slim

LABEL maintainer="benoit.pourre@doca-consulting.fr"
LABEL source="https://gitlab.com/captnbp/code-server-hub"

COPY ./nginx.conf	/etc/nginx/nginx.conf

COPY --chown=nginx 30-oauth.sh /docker-entrypoint.d/30-oauth.sh
RUN  chmod +x /docker-entrypoint.d/30-oauth.sh