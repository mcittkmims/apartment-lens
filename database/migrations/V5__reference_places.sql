-- ref: where streets and buildings are, from public sources (cadastre, OpenStreetMap, map.md).
-- Used by the scraper to turn addresses into map points. Every row records its source, so a source
-- can be refreshed or removed on its own.
create schema ref;

create table ref.source (
    code        text primary key,               -- cadastre, osm, mapmd
    name        text not null,
    licence     text not null,
    imported_at timestamptz
);

insert into ref.source (code, name, licence) values
    ('cadastre', 'Cadastre of the Republic of Moldova (geodata.gov.md)', 'public register data (Law 151/2017)'),
    ('osm', 'OpenStreetMap (Geofabrik extract)', 'ODbL 1.0, © OpenStreetMap contributors'),
    ('mapmd', 'map.md street pages (Simpals)', 'no published licence');

-- Communes, towns and municipalities with their official boundaries (cadastre UAT-1).
create table ref.admin_area (
    id          bigint generated always as identity primary key,
    source      text not null references ref.source,
    full_name   text not null,                   -- "r-nul Ialoveni, or. Ialoveni"
    name        text not null,                   -- "Ialoveni"
    kind        text,                            -- mun, or, com, sat
    geom        geography(multipolygon, 4326) not null,
    unique (source, full_name)
);
create index admin_area_geom on ref.admin_area using gist (geom);

-- Towns and villages, with the commune and district they belong to.
create table ref.locality (
    id          bigint generated always as identity primary key,
    source      text not null references ref.source,
    full_name   text not null,                   -- "mun. Chișinău, com. Ciorescu, sat. Goian"
    name        text not null,                   -- "Goian"
    kind        text,                            -- mun, or, sat
    commune     text,                            -- "Ciorescu"
    district    text,                            -- "Chișinău" (municipality or raion)
    point       geography(point, 4326),          -- centre of its addresses
    unique (source, full_name)
);

-- One street of one locality, from one source.
create table ref.street (
    id          bigint generated always as identity primary key,
    source      text not null references ref.source,
    source_id   text,                            -- id at the source, when it has one
    locality    text,                            -- locality full name, as in ref.locality
    type        text not null,                   -- street, lane, boulevard, highway, avenue, ...
    name_ro     text not null default '',
    name_ru     text not null default '',
    aliases     text[] not null default '{}',    -- old, alternative and variant spellings
    geom        geography(multilinestring, 4326),
    same_as     bigint references ref.street,    -- the cadastre street this one is (set for other sources)
    unique (source, source_id)
);
create index street_geom on ref.street using gist (geom);
create index street_locality on ref.street (locality);

-- House numbers with their position.
create table ref.address_point (
    id          bigint generated always as identity primary key,
    source      text not null references ref.source,
    street_id   bigint references ref.street on delete cascade,
    locality    text,
    street_text text,                            -- the street as the source wrote it
    number      text not null,
    geom        geography(point, 4326) not null
);
create index address_point_geom on ref.address_point using gist (geom);
create index address_point_street on ref.address_point (street_id, number);

grant usage on schema ref to scraper;
grant select, insert, update, delete, truncate on all tables in schema ref to scraper;
