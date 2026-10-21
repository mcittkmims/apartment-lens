# Database

Apartment Lens uses one PostgreSQL database with PostGIS (map queries), pgvector (vector search) and pg_trgm (fuzzy text matching). The data is split into seven schemas, and each service has a database role that can write only to its own schemas.

## Core tables

```mermaid
erDiagram
    source ||--o{ listing : publishes
    listing ||--o{ listing_snapshot : "price history"
    listing ||--o{ listing_raw : "original content"
    building ||--o{ property : contains
    property ||--o{ property_listing : "linked to"
    listing ||--o{ property_listing : "linked to"
    listing ||--o{ listing_image : shows
    image ||--o{ listing_image : "appears in"
    image ||--o{ image_embedding : "has vector"
    image_cluster ||--o{ image : groups

    source {
        smallint id PK
        text code "999md or agency name"
        text kind "portal or agency"
    }
    listing {
        bigint id PK
        smallint source_id FK
        text external_id "ad id at the source"
        smallint rooms
        numeric area_m2
        smallint floor
        geography geom "map point"
        text location_precision "building, street, district or locality"
        bytea_array phone_hashes
        text_array crosslinks "the same ad on other sites"
        text status "active or gone"
    }
    listing_raw {
        bigint listing_id FK
        timestamptz fetched_at
        bytea body_gzip "as the source returned it"
    }
    listing_snapshot {
        bigint listing_id FK
        timestamptz captured_at
        numeric price_amount
        text price_currency
        numeric price_eur
        text status
    }
    building {
        bigint id PK
        geography geom
        text address
        text series "e.g. 143, bloc nou"
    }
    property {
        bigint id PK
        bigint building_id FK
        smallint rooms
        numeric area_m2
        smallint floor
    }
    property_listing {
        bigint property_id FK
        bigint listing_id FK
        timestamptz valid_from
        timestamptz valid_to "set when a link is undone"
    }
    image {
        bigint id PK
        bytea sha256 UK
        bit pdq "perceptual hash"
        text role "interior, exterior, render"
        bigint cluster_id FK
    }
    listing_image {
        bigint listing_id FK
        bigint image_id FK
        smallint position
    }
    image_embedding {
        bigint image_id FK
        text model
        halfvec vec "384 dimensions"
    }
    image_cluster {
        bigint id PK
        int distinct_units
        text scope "unit or building"
    }
```

## Schemas

| Schema | Tables | Holds | Written by |
|---|---|---|---|
| `ingest` | `source`, `listing`, `listing_raw`, `listing_snapshot`, `crawl_run`, `exchange_rate` | Ads as each source published them and cleaned up, their original content, price history and BNM rates | scraper |
| `catalog` | `building`, `property`, `property_listing`, `match_evidence` | Properties, and which ads belong to each one | core |
| `media` | `image`, `listing_image`, `image_embedding`, `image_cluster`, `pair_check` | Photos, their fingerprints and vectors, and same-room check results | scraper, vision |
| `social` | `video`, `video_frame`, `mention` | Videos submitted for search | vision, core |
| `app` | `user_account`, `saved_search`, `favorite`, `lens_query`, `match_report` | Users, their searches and their reports | core, vision |
| `ops` | `job`, `review_item` | The job queue and the manual review queue | all services |
| `ref` | `admin_area`, `locality`, `street`, `address_point` | Streets, house numbers and boundaries from the cadastre and OpenStreetMap, used to place ads on the map | scraper (imports) |

## Rules

**Price history.** A new `listing_snapshot` row is written only when the price or status changes. Each snapshot keeps the original price and currency plus a EUR value at that day's BNM rate.

**Original content.** `listing_raw` keeps each ad as the source returned it, stored again only when it changes, so the cleaned-up fields can be computed again with better rules. For sites that serve HTML pages it keeps an extract of what describes the property.

**Links between sites.** When a site names its copy of an ad on another site (an agency naming the 999.md ad), `crosslinks` records it, for example `999md:105689225`. The core service uses it as strong evidence that two ads are one property.

**Undoable grouping.** A wrong link between an ad and a property is closed by setting `valid_to`, never deleted, so every grouping decision can be reversed.

**Photos.** One photo can appear in several ads, so photos link to ads through `listing_image`. A near-duplicate cluster used by ads with different floors or areas has `building` scope and never merges two properties.

**Vectors.** Each vector is stored with its model name, so a new model can be added next to the old one.

**Privacy.** The cleaned-up fields hold phone numbers only as keyed hashes; the original content keeps the numbers a site publishes. Private data a site returns but does not publish, such as an owner's phone or an agency's internal notes, is removed before anything is stored.

## Migrations

SQL migrations (Flyway) live in `database/migrations/`. The `migrate` service in Docker Compose applies them before the other services start, and sets each service role's password.
