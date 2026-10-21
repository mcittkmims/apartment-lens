-- The agency websites and the classifieds sites besides 999.md, and what their ads need.
insert into ingest.source (id, code, kind, name, base_url)
values (2, 'proimobil', 'agency', 'Proimobil', 'https://proimobil.md'),
       (3, 'casamare', 'portal', 'CasaMare', 'https://casamare.md'),
       (4, 'carpatics', 'portal', 'Carpatics', 'https://carpatics.md'),
       (5, 'okeyimobil', 'agency', 'OkeyImobil', 'https://okeyimobil.md'),
       (6, 'realist', 'agency', 'Realist', 'https://www.realist.md'),
       (7, 'romanescu', 'agency', 'Romanescu', 'https://romanescu.md');

alter table ingest.listing
    -- Sites whose listing pages show only a summary of each ad: the summary last seen, so the full ad is
    -- read again only when it changed, and when the full ad was last read.
    add column summary_sha256    bytea,
    add column detail_fetched_at timestamptz,
    -- A pin the site placed only near the property (a circle of this many metres); null for a pin on it.
    add column pin_radius_m      integer check (pin_radius_m > 0),
    -- The same ad on other sites, as the site itself names them: "999md:105689225".
    add column crosslinks        text[] not null default '{}';
