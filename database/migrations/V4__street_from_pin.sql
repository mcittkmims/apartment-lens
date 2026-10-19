-- A street can be taken from the buildings at the seller's own pin when the text names none.
alter table ingest.listing drop constraint listing_street_match_check,
    add constraint listing_street_match_check
        check (street_match in ('exact', 'alias', 'partial', 'fuzzy', 'nearby', 'from_pin', 'unresolved'));

-- A neighbourhood, residential complex or cottage area written where the street belongs
-- ("Cartierul Cluj", "Satul German").
alter table ingest.listing add column area_name text;
