-- The address data (ref) is loaded by its own tool (database/geodata) under its own role; the scraper only
-- reads it.
do $$
begin
    if not exists (select from pg_roles where rolname = 'geodata') then
        create role geodata nologin;
    end if;
end
$$;

grant usage, create on schema ref to geodata;
grant select, insert, update, delete, truncate on all tables in schema ref to geodata;

-- osm2pgsql drops and creates its staging tables on every load, so the role must own them.
do $$
declare
    t text;
begin
    for t in select tablename from pg_tables where schemaname = 'ref' and tableowner = 'scraper' loop
        execute format('alter table ref.%I owner to geodata', t);
    end loop;
end
$$;

revoke create on schema ref from scraper;
revoke insert, update, delete, truncate on all tables in schema ref from scraper;
grant select on all tables in schema ref to scraper;
-- Tables the loader creates later (the staging tables) are readable by the scraper too.
alter default privileges for role geodata in schema ref grant select on tables to scraper;
