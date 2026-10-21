#!/bin/sh
# Refreshes the address data in the ref schema: the cadastre from geodata.gov.md, then OpenStreetMap
# (osm2pgsql loads the Moldova extract into staging tables, which are then linked to the cadastre).
# "cadastre" refreshes only the cadastre and links the OpenStreetMap streets loaded before to it again;
# "osm" refreshes only OpenStreetMap. Each part keeps the previous data if it fails.
set -eu
part="${1:-all}"
case "$part" in
    all|cadastre|osm) ;;
    *) echo "usage: refresh.sh [cadastre | osm]" >&2; exit 2 ;;
esac
if [ "$part" != osm ]; then
    java -jar /app/geodata.jar cadastre
fi
if [ "$part" != cadastre ]; then
    /app/osm/load.sh
fi
java -jar /app/geodata.jar osm
echo "Address data refreshed. Restart the scraper so it reads it: docker compose restart scraper"
