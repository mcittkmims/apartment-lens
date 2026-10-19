-- The seller's pin as published, kept apart from the map point: a default pin (999.md's centre of the
-- chosen town or sector, left unmoved) is not used as the location, but stays visible.
alter table ingest.listing add column pin geography(point, 4326);
create index listing_pin on ingest.listing using gist (pin);

-- Map points can now come from the map's address points (street and house number), and streets can be
-- recognized from the buildings around the seller's pin.
alter table ingest.listing drop constraint listing_location_source_check,
    add constraint listing_location_source_check
        check (location_source in ('pin', 'address', 'street', 'place'));
alter table ingest.listing drop constraint listing_street_match_check,
    add constraint listing_street_match_check
        check (street_match in ('exact', 'alias', 'partial', 'fuzzy', 'nearby', 'unresolved'));
