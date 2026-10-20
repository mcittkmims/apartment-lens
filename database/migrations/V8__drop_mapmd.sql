-- map.md is no longer a source: it publishes no licence, and measured on every ad it fixed few streets
-- while adding wrong matches. Its streets go, and with them the line-only links only it produced.
update ref.street set same_as = null where same_as in (select id from ref.street where source = 'mapmd');
delete from ref.address_point where source = 'mapmd';
delete from ref.street where source = 'mapmd';
delete from ref.locality where source = 'mapmd';
delete from ref.admin_area where source = 'mapmd';
delete from ref.source where code = 'mapmd';

alter table ref.street drop column link_basis;
