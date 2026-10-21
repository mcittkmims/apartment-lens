# Address data tool

Loads the streets, house numbers and places of Moldova into the `ref` schema, which the scraper uses to place ads on the map. Run it once, then every few months:

```sh
docker compose run --rm geodata          # cadastre, then OpenStreetMap
docker compose restart scraper           # the scraper reads the data when it starts
```

`docker compose run --rm geodata cadastre` or `... geodata osm` refreshes one source.

| Source | What it gives | How it is read |
|---|---|---|
| Cadastre of the Republic of Moldova (geodata.gov.md) | Official street names and lines, house numbers, commune and town boundaries | Its public map service, 10,000 features per request |
| OpenStreetMap (Geofabrik extract) | Russian and old street names, more house numbers, places on the left bank of the Dniester, populations | The daily Moldova extract, unpacked by osm2pgsql (`osm/moldova.lua`) into staging tables, then linked to the cadastre's streets |

Each source replaces its own rows in one transaction, so a failed or partial download keeps the previous data. The tool connects as the `geodata` database role, the only one that can write `ref`.

Built with Java 25 and Spring Boot, plus osm2pgsql in the same image. `Text`, `StreetTypes` and `PoliteHttpClient` are copies of the scraper's; keep them in step. Tests: `./gradlew test`.

Data: Cadastre of the Republic of Moldova (geodata.gov.md); © OpenStreetMap contributors, available under the Open Database License.
