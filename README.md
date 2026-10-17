# Apartment Lens

Every flat and house for sale in Moldova on one map. Ads from 999.md and real-estate agency websites are grouped into one card per property, with its price history across all sources. Photo and video search finds the property behind a picture.

> **Status:** design stage. These READMEs describe the plan; there is no code yet.

## Repositories

This repo ties the services together. Each service lives in its own repo, linked here as a git submodule.

| Repo | Path here | Language | Job |
|---|---|---|---|
| [listing-frontend](https://github.com/mcittkmims/listing-frontend) | `services/frontend` | TypeScript | The website: map, filters, property pages, photo and video search |
| [listing-core](https://github.com/mcittkmims/listing-core) | `services/core` | Java | Backend API, map search, same-flat matching, review queue |
| [listing-scraper](https://github.com/mcittkmims/listing-scraper) | `services/scraper` | Java | Collects ads from 999.md and agency websites; saves ads, prices and photos |
| [listing-vision](https://github.com/mcittkmims/listing-vision) | `services/vision` | Python | Photo fingerprints, vectors, photo and video search |

The shared database is described in [`database/`](database/README.md).

```
git clone --recurse-submodules https://github.com/mcittkmims/apartment-lens.git
```

## How it fits together

```mermaid
flowchart LR
    users([Users])
    frontend["Frontend"]

    subgraph server["Server"]
        proxy["Reverse proxy"]
        core["Core service"]
        vonline["Vision worker · online"]
        scraper["Scraper service"]
        db[("Database")]
        store[("Photo storage")]
        geo["Geocoder"]
    end

    subgraph gpu["GPU machine"]
        vbatch["Vision worker · batch"]
    end

    sources([Listing sources])

    users --> frontend
    frontend -->|HTTPS| proxy
    proxy -->|API calls| core
    core <--> db
    vonline <-->|jobs| db
    vonline --> store
    scraper -->|ads, prices| db
    scraper -->|photos| store
    scraper -->|addresses| geo
    scraper --->|crawls| sources
    db <-.->|daily jobs| vbatch
    store -.-> vbatch
```

### Components

| Component | What it does | Built with |
|---|---|---|
| Frontend | The website users see: map, property pages, photo and video search | TypeScript, React, MapLibre |
| Reverse proxy | Only public entry point: HTTPS, serves the website and photos, forwards API calls to the core service | Caddy, Cloudflare Tunnel |
| Core service | REST API, map search, groups ads into flats, review queue, alerts | Java, Spring Boot |
| Scraper service | Crawls 999.md and agency websites, cleans up each ad, saves ads, price changes and photos | Java, jsoup |
| Geocoder | Turns an address into a point on the map, and a point into a district | Nominatim |
| Database | Ads, flats, price history, photo vectors, job queue | PostgreSQL, PostGIS, pgvector |
| Photo storage | Photo files from ads and user uploads | Files on disk |
| Vision worker · online | Fingerprints new photos; answers photo and video searches | Python, DINOv2, PDQ |
| Vision worker · batch | Once a day: vectors for new photos, same-room checks on look-alike photos | Python, DINOv2, LightGlue |

## How it works

1. **The scraper service** crawls 999.md and agency websites every few hours. It normalizes every ad (price to EUR, rooms, m², floor, address, map point) and saves the ad, a price snapshot when something changed, and any new photos.
2. **The online vision worker** fingerprints each new photo within seconds (SHA-256 and PDQ hash). Copies of the same ad across sources connect right away.
3. **The core service** matches each new ad against known flats using facts, location, text and photo evidence. It links the ad to a flat, or puts unclear pairs in the review queue.
4. **Once a day, the batch vision worker runs on a GPU machine.** It computes vectors for the day's new photos and checks look-alike photo pairs. The core service then re-matches the day's new ads with that evidence.
5. **Users use the frontend in their browser:** map, property pages with every source's ad and price history, and photo or video search. The browser loads the frontend from the reverse proxy, the server's only public entry point. After that, the frontend talks to the core service's API through the same proxy. Searches go through the job queue to the online vision worker.

## Design rules

- **Services talk only through the database.** Backend services never call each other over HTTP; work is handed over through the `ops.job` table. The batch worker can be offline without breaking anything; its jobs wait.
- **The frontend only talks to the core service's API.** It never touches the database.
- **The vision workers collect evidence; the core service decides.** Every "same flat?" rule lives in one place.
- **Prefer a missed merge to a wrong one.** Ads are linked to flats with rows that can be undone, never merged destructively.
- **Keep the raw data.** Raw pages are stored so normalization can be re-run when a rule improves.
- **No gateway, message broker or Kubernetes.** One public API, one database, Docker Compose.

## Build order

1. Scraper for 999.md, price history, and the map. Start crawling first: price history only exists from the day you start recording it.
2. Agency websites, grouping by identical photos plus simple rules, then vector search and photo search.
3. Video search.
4. Alerts, and a matcher trained on review decisions.
