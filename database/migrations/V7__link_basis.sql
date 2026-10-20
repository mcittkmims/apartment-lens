-- Why a street was linked to the street it is: by similar names, or only because its line lies on it
-- (names that may be translations, old names or mistakes; used only where the seller's pin confirms them).
alter table ref.street add column link_basis text check (link_basis in ('name', 'line'));
