FROM debian:12

COPY    ./install_tools.sh /usr/local/bin/install_tools.sh
COPY    ./docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENV     LANG=en_US.UTF-8

USER    root
RUN     /usr/local/bin/install_tools.sh

RUN curl -L "https://github.com/cdr/code-server/releases/download/v4.20.0/code-server_4.20.0_$(dpkg --print-architecture).deb" -o /tmp/code-server.deb && \
    dpkg -i /tmp/code-server.deb && rm /tmp/code-server.deb

EXPOSE 8080
# This way, if someone sets $DOCKER_USER, docker-exec will still work as
# the uid will remain the same. note: only relevant if -u isn't passed to
# docker-run.
USER    1000
ENV     USER=coder
WORKDIR /home/coder
USER    coder

ENV     ZSH_CACHE_DIR=/tmp

ENTRYPOINT      ["dumb-init", "docker-entrypoint.sh"]
CMD     ["code-server"]