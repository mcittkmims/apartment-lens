# Database

The backend services never call each other. They share one PostgreSQL database, so this folder is their contract: what lives where, and who may write it. The frontend never touches the database; it goes through the core service's API.

**Extensions:** PostGIS (map queries), pgvector (vector search), pg_trgm (fuzzy text matching), unaccent.

## Schemas

| Schema | Holds | Written by | Read by |
|---|---|---|---|
| `ingest` | Sources (999.md, agency websites), ads as each source shows them, price snapshots, crawl runs | scraper | core, vision |
| `catalog` | Buildings, flats (properties), ad-to-flat links, match evidence | core | core |
| `media` | Photos (file path, SHA-256, PDQ hash, type), vectors, near-duplicate groups, same-room check scores | scraper adds photo rows; vision adds hashes, vectors, scores | core, vision |
| `social` | Videos, their frames, mentions of a flat (later) | vision, core | core |
| `app` | Users, saved searches, favorites, photo/video searches and their results | core; vision writes search results | core |
| `ops` | Job queue, review queue | all services | all services |

Each service gets its own database role that can only write to its schemas.

## Key ideas

- **Two levels: building and flat.** A building has flats; a flat has ads from one or more sources; an ad has price snapshots.
- **Snapshots only on change.** A new price row is written only when the price or status changes, not on every crawl.
- **Links, not merges.** An ad joins a flat through a link row with `valid_from` and `valid_to`, so a wrong grouping can be undone.
- **Photos link to ads through a separate table.** One photo can appear in several ads, and its vector is stored by photo ID.
- **Vectors carry their model name.** Switching to a new model writes new rows next to the old ones; you swap over when they're ready.
- **Prices in EUR.** The original price and currency are kept, plus a EUR value at that day's official BNM rate.

## Migrations

SQL migrations (Flyway) will live in `database/migrations/` and are applied before the services start. Not written yet.
