#!/bin/bash
set -eu

touch /home/coder/.zshrc

if [ "$1" = 'code-server' ]; then
  exec /usr/bin/code-server --bind-addr 0.0.0.0:8080 --auth none /home/coder
fi

exec "$@"