# PostgreSQL with PostGIS (map queries) and pgvector (image vectors).
# Built on the official multi-architecture image, which ships the PostgreSQL apt repository.
FROM postgres:18-trixie

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      postgresql-18-postgis-3 \
      postgresql-18-postgis-3-scripts \
      postgresql-18-pgvector \
 && rm -rf /var/lib/apt/lists/*
