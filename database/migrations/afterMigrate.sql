-- Runs after every migration. Sets each service role's login password from a Flyway placeholder
-- (FLYWAY_PLACEHOLDERS_SCRAPER_PASSWORD, FLYWAY_PLACEHOLDERS_GEODATA_PASSWORD); an empty value leaves the
-- role unable to log in.
do $$
begin
    if '${scraper_password}' <> '' then
        execute format('alter role scraper login password %L', '${scraper_password}');
    end if;
    if '${geodata_password}' <> '' then
        execute format('alter role geodata login password %L', '${geodata_password}');
    end if;
end
$$;
