-- osm2pgsql flex style: only what the address normalizer needs.
-- Named roads with their names in every language, every address point, and named places.

local ways = osm2pgsql.define_way_table('osm_way', {
    { column = 'highway', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'name_ro', type = 'text' },
    { column = 'name_ru', type = 'text' },
    { column = 'old_name', type = 'text' },
    { column = 'old_name_ru', type = 'text' },
    { column = 'alt_name', type = 'text' },
    { column = 'alt_name_ru', type = 'text' },
    { column = 'geom', type = 'linestring', projection = 4326, not_null = true },
}, { schema = 'ref' })

local addresses = osm2pgsql.define_table({
    name = 'osm_address',
    schema = 'ref',
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'street', type = 'text' },
        { column = 'housenumber', type = 'text' },
        { column = 'city', type = 'text' },
        { column = 'geom', type = 'point', projection = 4326, not_null = true },
    },
})

local places = osm2pgsql.define_node_table('osm_place', {
    { column = 'place', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'name_ro', type = 'text' },
    { column = 'name_ru', type = 'text' },
    { column = 'population', type = 'text' },
    { column = 'geom', type = 'point', projection = 4326, not_null = true },
}, { schema = 'ref' })

local place_kinds = { city = true, town = true, village = true, hamlet = true,
                      suburb = true, quarter = true, neighbourhood = true }

local skip = { track = true, path = true, footway = true, cycleway = true, steps = true,
               bridleway = true, proposed = true, abandoned = true, construction = true }

local function address(object, geom)
    local t = object.tags
    if t['addr:housenumber'] and t['addr:street'] then
        addresses:insert({ street = t['addr:street'], housenumber = t['addr:housenumber'],
                           city = t['addr:city'], geom = geom })
    end
end

function osm2pgsql.process_node(object)
    address(object, object:as_point())
    local t = object.tags
    if t.place and t.name and place_kinds[t.place] then
        places:insert({ place = t.place, name = t.name, name_ro = t['name:ro'], name_ru = t['name:ru'],
                        population = t.population, geom = object:as_point() })
    end
end

function osm2pgsql.process_way(object)
    local t = object.tags
    if t.highway and t.name and not skip[t.highway] then
        ways:insert({ highway = t.highway, name = t.name, name_ro = t['name:ro'], name_ru = t['name:ru'],
                      old_name = t.old_name, old_name_ru = t['old_name:ru'], alt_name = t.alt_name,
                      alt_name_ru = t['alt_name:ru'], geom = object:as_linestring() })
    end
    if object.is_closed then
        address(object, object:as_polygon():centroid())
    end
end

function osm2pgsql.process_relation(object)
    if object.tags.type == 'multipolygon' then
        address(object, object:as_multipolygon():centroid())
    end
end
