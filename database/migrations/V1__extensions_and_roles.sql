-- Extensions used across the system.
create extension if not exists postgis;
create extension if not exists vector;
create extension if not exists pg_trgm;
create extension if not exists unaccent;

-- One role per service. Roles start without login; afterMigrate.sql gives them a password.
do $$
begin
    if not exists (select from pg_roles where rolname = 'scraper') then
        create role scraper nologin;
    end if;
end
$$;
