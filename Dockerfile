FROM python:3.11 AS builder

ENV PIP_ROOT_USER_ACTION=ignore

RUN mkdir -p /build
RUN pip install --upgrade pip && \
    pip install poetry
COPY pyproject.toml /build/pyproject.toml
COPY README.md /build/README.md
COPY elastic_datashader /build/elastic_datashader
WORKDIR /build/elastic_datashader
RUN poetry build

FROM python:3.11-slim AS deployment
LABEL maintainer="foss@spectric.com"
RUN useradd -d /home/datashader datashader && \
    mkdir -p /home/datashader /opt/elastic_datashader/tms-cache && \
    chown -R datashader:datashader /home/datashader /opt/elastic_datashader

USER datashader
RUN mkdir /home/datashader/tmp
COPY --from=builder /build/dist/*.whl /home/datashader/tmp/
ENV PATH="$PATH:/home/datashader/.local/bin"
RUN pip install --upgrade pip && \
    pip install --no-cache-dir /home/datashader/tmp/*.whl && \
    pip install gunicorn==22.0.0 && \
    pip install uvicorn==0.24.0

COPY deployment/logging_config.yml /opt/elastic_datashader/
COPY deployment/gunicorn_config.py /opt/elastic_datashader/

VOLUME ["/opt/elastic_datashader/tms-cache"]
ENV DATASHADER_CACHE_DIRECTORY=/opt/elastic_datashader/tms-cache


ENTRYPOINT [ "gunicorn", \
    "--ssl-version","TLSv1_2", \
    "--ciphers","ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384", \
    "--chdir", "/opt/elastic_datashader", \
    "-c", "/opt/elastic_datashader/gunicorn_config.py", \
    "--max-requests", "400", \
    "--workers", "30", \
    "-k", "uvicorn.workers.UvicornWorker", \
    "elastic_datashader:app" \
]
