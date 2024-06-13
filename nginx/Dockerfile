FROM    nginxinc/nginx-unprivileged:1.27-alpine-slim

COPY ./nginx.conf	/etc/nginx/nginx.conf

COPY --chown=nginx 30-oauth.sh /docker-entrypoint.d/30-oauth.sh
RUN  chmod +x /docker-entrypoint.d/30-oauth.sh