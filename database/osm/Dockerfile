# Loads the OpenStreetMap extract of Moldova into staging tables (ref.osm_way, ref.osm_address, ref.osm_place).
FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends osm2pgsql curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY moldova.lua load.sh /osm/
RUN chmod +x /osm/load.sh
ENTRYPOINT ["/osm/load.sh"]
