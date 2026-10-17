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
    sources([999.md and agency websites])

    subgraph server["Server, always on"]
        proxy["Reverse proxy"]
        frontend["Frontend<br/>web app"]
        core["Core service<br/>API, search, matching"]
        scraper["Scraper service"]
        db[("PostgreSQL<br/>data and job queue")]
        store[("Photo storage")]
        geo["Geocoder"]
        vonline["Vision worker, online<br/>photo hashes, photo and video search"]
    end

    subgraph gpu["GPU worker, runs daily"]
        vbatch["Vision worker, batch<br/>vectors, same-room checks"]
    end

    users -->|HTTPS| proxy
    proxy -->|web app files| frontend
    proxy -->|API calls| core
    scraper -->|crawls| sources
    scraper -->|ads, prices| db
    scraper -->|photos| store
    scraper -->|addresses| geo
    core <-->|SQL| db
    vonline <-->|jobs and results| db
    vonline -->|reads| store
    vbatch -.->|jobs and results| db
    vbatch -.->|reads| store
```

## How it works

1. **The scraper service** crawls 999.md and agency websites every few hours. It normalizes every ad (price to EUR, rooms, m², floor, address, map point) and saves the ad, a price snapshot when something changed, and any new photos.
2. **The online vision worker** fingerprints each new photo within seconds (SHA-256 and PDQ hash). Copies of the same ad across sources connect right away.
3. **The core service** matches each new ad against known flats using facts, location, text and photo evidence. It links the ad to a flat, or puts unclear pairs in the review queue.
4. **Once a day, the batch vision worker runs on a GPU machine.** It computes vectors for the day's new photos and checks look-alike photo pairs. The core service then re-matches the day's new ads with that evidence.
5. **Users use the frontend:** map, property pages with every source's ad and price history, and photo or video search. The frontend only talks to the core service's API. Searches go through the job queue to the online vision worker.

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
