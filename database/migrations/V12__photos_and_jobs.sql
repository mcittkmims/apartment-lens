-- media: the photos of the ads, each stored once by the hash of its content.
-- ops: the job queue the services use to hand work to each other.
create schema media;
create schema ops;

-- One file, however many ads and sites show it.
create table media.image (
    id           bigint generated always as identity primary key,
    sha256       bytea not null unique,
    bytes        integer not null check (bytes > 0),
    content_type text not null,                     -- image/jpeg, image/webp, image/png
    stored_at    timestamptz not null default now()
);

-- A photo as one site names it (its stable key: an id, a file name, a link without its signature), downloaded
-- once; ads of the same site that show it again do not download it again.
create table media.source_photo (
    source_id       smallint not null references ingest.source,
    photo_key       text not null,
    image_id        bigint references media.image,  -- null until downloaded
    attempts        smallint not null default 0,
    last_attempt_at timestamptz,
    last_error      text,
    primary key (source_id, photo_key)
);
create index source_photo_pending on media.source_photo (last_attempt_at nulls first) where image_id is null;

-- The photos of an ad, in the ad's order.
create table media.listing_image (
    listing_id bigint not null references ingest.listing on delete cascade,
    position   smallint not null,
    source_id  smallint not null,
    photo_key  text not null,
    primary key (listing_id, position),
    foreign key (source_id, photo_key) references media.source_photo
);
create index listing_image_photo on media.listing_image (source_id, photo_key);

create table ops.job (
    id          bigint generated always as identity primary key,
    kind        text not null,                      -- e.g. image.fingerprint
    payload     jsonb not null,
    status      text not null default 'queued' check (status in ('queued', 'running', 'done', 'failed')),
    attempts    smallint not null default 0,
    created_at  timestamptz not null default now(),
    run_after   timestamptz not null default now(),
    started_at  timestamptz,
    finished_at timestamptz,
    error       text
);
create index job_queued on ops.job (kind, run_after) where status = 'queued';

-- The photos of the ads stored so far.
insert into media.source_photo (source_id, photo_key)
select distinct l.source_id, k.key
from ingest.listing l, unnest(l.photo_keys) as k(key)
on conflict do nothing;
insert into media.listing_image (listing_id, position, source_id, photo_key)
select l.id, (k.n - 1)::smallint, l.source_id, k.key
from ingest.listing l, unnest(l.photo_keys) with ordinality as k(key, n);

grant usage on schema media, ops to scraper;
grant select, insert, update, delete on media.image, media.source_photo, media.listing_image to scraper;
grant select, insert on ops.job to scraper;
