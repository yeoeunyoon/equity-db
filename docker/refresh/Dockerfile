# Data-refresh worker: regenerates data/*.tsv from the live S&P 500 + Yahoo
# Finance and reloads MySQL on a daily schedule. Build context is the repo root
# (see docker-compose.yml) so requirements.txt is available here; the app code
# (generate_data.py, docker/reload.sql) is bind-mounted at /app at runtime.
FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY docker/refresh/entrypoint.sh /usr/local/bin/refresh-entrypoint.sh
RUN chmod +x /usr/local/bin/refresh-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/refresh-entrypoint.sh"]
