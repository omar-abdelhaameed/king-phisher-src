FROM python:3.7-slim-buster

# buster is EOL — official repos are gone, archive.debian.org still has it
RUN printf '%s\n' \
    'deb http://archive.debian.org/debian buster main' \
    'deb http://archive.debian.org/debian-security buster/updates main' \
    > /etc/apt/sources.list \
    && printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99no-check-valid-until

# Full dependency list your last successful build actually needed
# (pkg-config/libgeos/libgirepository/libcairo/libgtk — without these,
# pygobject's pycairo dependency fails to compile), plus procps/curl/
# iproute2 so the container is debuggable, plus openssh-server for the
# client's RPC tunnel.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libpq-dev \
    libffi-dev \
    libssl-dev \
    libgeos-dev \
    libgirepository1.0-dev \
    libcairo2-dev \
    libgtk-3-dev \
    git \
    procps \
    curl \
    iproute2 \
    openssh-server \
    && mkdir /var/run/sshd \
    && rm -rf /var/lib/apt/lists/*

# RPC auth is PAM-checked by the king_phisher.server process itself, so
# the account needs to live in this image, not just on the Docker host.
RUN useradd -m -s /bin/bash kpadmin \
    && echo 'kpadmin:omar' | chpasswd \
    && sed -i 's/#AllowTcpForwarding.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config

RUN pip install --no-cache-dir "pip<23" "setuptools<60" "pipenv==2018.11.26"

WORKDIR /opt/king-phisher
COPY . /opt/king-phisher

RUN mkdir -p /var/king-phisher \
    && chmod 777 /var/king-phisher \
    && pipenv --python /usr/local/bin/python \
    && pipenv install --skip-lock \
    && pipenv run pip install "markupsafe==2.0.1"

COPY entrypoint.sh /opt/king-phisher/entrypoint.sh
RUN chmod +x /opt/king-phisher/entrypoint.sh

EXPOSE 80 22

ENTRYPOINT ["/opt/king-phisher/entrypoint.sh"]
