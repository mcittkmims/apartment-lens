-- ingest: ads as each source published them, cleaned up, with their price history.
-- Written only by the scraper.
create schema ingest;

create table ingest.source (
    id       smallint primary key,
    code     text not null unique,
    kind     text not null check (kind in ('portal', 'agency')),
    name     text not null,
    base_url text not null
);

insert into ingest.source (id, code, kind, name, base_url)
values (1, '999md', 'portal', '999.md', 'https://999.md');

create table ingest.crawl_run (
    id               bigint generated always as identity primary key,
    source_id        smallint not null references ingest.source,
    started_at       timestamptz not null default now(),
    finished_at      timestamptz,
    status           text not null default 'running'
                     check (status in ('running', 'completed', 'partial', 'failed')),
    advertised_total integer,             -- number of ads the source says it has
    requests         integer not null default 0,
    ads_seen         integer not null default 0,
    ads_new          integer not null default 0,
    ads_changed      integer not null default 0,
    price_changes    integer not null default 0,
    ads_gone         integer not null default 0,
    errors           integer not null default 0,
    error            text
);

create index crawl_run_source_started on ingest.crawl_run (source_id, started_at desc);
-- At most one running crawl per source.
create unique index crawl_run_one_running on ingest.crawl_run (source_id) where status = 'running';

-- Official BNM exchange rates, used to convert prices to EUR.
create table ingest.exchange_rate (
    rate_date    date not null,
    currency     char(3) not null,
    mdl_per_unit numeric(12, 4) not null check (mdl_per_unit > 0),
    fetched_at   timestamptz not null default now(),
    primary key (rate_date, currency)
);

create table ingest.listing (
    id                 bigint generated always as identity primary key,
    source_id          smallint not null references ingest.source,
    external_id        text not null,                       -- ad id at the source
    url                text not null,
    status             text not null check (status in ('active', 'gone')),
    first_seen_at      timestamptz not null,
    last_seen_at       timestamptz not null,
    gone_at            timestamptz,
    posted_at          timestamptz,
    republished_at     timestamptz,
    content_sha256     bytea not null,                      -- hash of the current raw content
    normalizer_version integer not null,
    normalized_at      timestamptz not null,

    -- What is offered
    property_type      text not null
                       check (property_type in ('apartment', 'room', 'house', 'townhouse', 'duplex',
                                                'villa', 'country_house')),
    seller_type        text check (seller_type in ('owner', 'agency', 'developer', 'bank')),
    seller_name        text,
    seller_account     text,
    title              text,
    description_ro     text,
    description_ru     text,

    -- Price (also kept per change in listing_snapshot)
    price_amount       numeric(14, 2),
    price_currency     char(3),
    price_eur          numeric(14, 2),
    price_per_m2_eur   numeric(10, 2),
    price_negotiable   boolean,
    down_payment       numeric(14, 2),

    -- Unit facts
    rooms              smallint check (rooms between 1 and 50),
    rooms_open_ended   boolean not null default false,      -- "5 or more"
    has_living_room    boolean,
    area_total_m2      numeric(9, 2) check (area_total_m2 > 0),
    area_living_m2     numeric(9, 2) check (area_living_m2 > 0),
    area_kitchen_m2    numeric(9, 2) check (area_kitchen_m2 > 0),
    land_area_m2       numeric(12, 2) check (land_area_m2 > 0),
    floor              smallint check (floor between -3 and 60),
    floor_kind         text check (floor_kind in ('basement', 'semi_basement', 'attic', 'penthouse')),
    floors_total       smallint check (floors_total between 1 and 60),
    bathrooms          smallint,
    balconies          smallint,
    ceiling_height_m   numeric(4, 2),

    -- Building
    housing_stock      text check (housing_stock in ('new_build', 'secondary')),
    building_material  text,
    building_series    text,
    condition          text,
    developer          text,
    parking            text,

    -- Address, as published and cleaned up
    region             text,
    locality           text,
    district           text,
    region_code        integer,                             -- source option ids
    locality_code      integer,
    district_code      integer,
    street_raw         text,
    house_number_raw   text,
    street_type        text,
    street_name        text,
    street_match       text check (street_match in ('exact', 'alias', 'partial', 'fuzzy', 'unresolved')),
    house_number       text,

    -- Map point
    geom               geography(point, 4326),
    location_source    text check (location_source in ('pin', 'street', 'place')),
    location_precision text check (location_precision in ('building', 'street', 'district', 'locality')),

    -- Contacts and media
    phone_hashes       bytea[] not null default '{}',       -- keyed hashes of +373 numbers
    photo_keys         text[] not null default '{}',        -- source photo ids, in order
    has_video          boolean not null default false,
    amenities          text[] not null default '{}',

    -- Values the normalizer could not read, with the reason
    issues             jsonb not null default '[]',

    unique (source_id, external_id)
);

create index listing_geom on ingest.listing using gist (geom);
create index listing_status on ingest.listing (source_id, status, last_seen_at);
create index listing_phone on ingest.listing using gin (phone_hashes);
create index listing_street on ingest.listing (locality, street_name, house_number);

-- The raw content of each ad, stored again only when it changes, so normalization can be re-run.
create table ingest.listing_raw (
    id           bigint generated always as identity primary key,
    listing_id   bigint not null references ingest.listing on delete cascade,
    crawl_run_id bigint references ingest.crawl_run,
    fetched_at   timestamptz not null,
    sha256       bytea not null,
    body_gzip    bytea not null,
    unique (listing_id, sha256)
);

create index listing_raw_latest on ingest.listing_raw (listing_id, fetched_at desc);

-- Price history: one row when an ad is first seen, then one per price or status change.
create table ingest.listing_snapshot (
    id             bigint generated always as identity primary key,
    listing_id     bigint not null references ingest.listing on delete cascade,
    crawl_run_id   bigint references ingest.crawl_run,
    captured_at    timestamptz not null,
    status         text not null check (status in ('active', 'gone')),
    price_amount   numeric(14, 2),
    price_currency char(3),
    price_eur      numeric(14, 2)
);

create index listing_snapshot_listing on ingest.listing_snapshot (listing_id, captured_at);

-- Access: the scraper writes, everyone else may only read (granted when their roles exist).
grant usage on schema ingest to scraper;
grant select, insert, update, delete on all tables in schema ingest to scraper;
