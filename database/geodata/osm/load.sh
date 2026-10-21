#!/bin/sh
# Downloads the current Moldova extract from Geofabrik and loads it with osm2pgsql.
set -eu
URL="${OSM_EXTRACT_URL:-https://download.geofabrik.de/europe/moldova-latest.osm.pbf}"
curl -fsSL -A "apartment-lens/1.0 (+https://github.com/mcittkmims/apartment-lens)" -o /tmp/moldova.osm.pbf "$URL"
ls -l /tmp/moldova.osm.pbf
osm2pgsql --create --slim --drop --output=flex --style=/app/osm/moldova.lua \
    --schema=ref --middle-schema=ref \
    --host="$PGHOST" --port="${PGPORT:-5432}" --database="$PGDATABASE" --user="$PGUSER" \
    /tmp/moldova.osm.pbf
echo "OpenStreetMap staging tables loaded"
