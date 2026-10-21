-- The latest working link of each photo, in the order of photo_keys, for sites whose links expire
-- (CasaMare signs its links for seven days; its ads are read again before that).
alter table ingest.listing add column photo_urls text[] not null default '{}';
