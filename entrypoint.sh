#!/bin/sh
set -e

/usr/sbin/sshd

exec pipenv run python -m king_phisher.server -L DEBUG data/server/king_phisher/server_config.yml
EOF
chmod +x entrypoint.sh

