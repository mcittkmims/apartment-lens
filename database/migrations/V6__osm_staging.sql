-- The OpenStreetMap loader (osm2pgsql, run as the scraper role) creates its staging tables in ref.
grant create on schema ref to scraper;
