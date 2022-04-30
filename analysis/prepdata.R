library(data.table)
library(sf)
library(tidycensus)
library(units)
library(readxl)

# Key for accessing US Census data. Obtain one at https://api.census.gov/data/key_signup.html 
API_KEY='PLEASE_OBTAIN AN API KEY FROM https://api.census.gov/data/key_signup.html'
census_api_key(API_KEY)


# SOURCES

# Stop-and-frisk (SQF) data from NYPD, 2019 and 2020. 
#     https://www1.nyc.gov/site/nypd/stats/reports-analysis/stopfrisk.page
#
# Census data (demographics etc.) from the American Community Survey (ACS) 2014--2019:
#     https://walker-data.com/tidycensus/articles/spatial-data.html
# See also the handy list of variables:
#     https://api.census.gov/data/2019/acs/acs5/variables.html
#
# Census tract shapefiles 2019 from US Census: 
#     https://www.census.gov/cgi-bin/geo/shapefiles/index.php?year=2019&layergroup=Census+Tracts
# Also, New York state shoreline: 
#     http://gis.ny.gov/gisdata/inventories/details.cfm?DSID=927
#
# Camera locations: data explained in https://github.com/amnesty-crisis-evidence-lab/decode-surveillance-nyc

# This script produces the following outputs:
#
# tracts
#    one row per census tract, with its geometry and borough
#    (except for two entirely-aquatic census tracts, which have been removed)
#    All geo coordinates are in EPSG 2908, the State Plane Coordinate System for NY/LongIsland
# census
#    one row per census tract (except for the two aquatic tracts)
# sqf
#    one row per stop-and-frisk incident in 2019 and 2020, geo-located, and labelled by census tract
#    (except for four records in 2020 with nonsense locations)
# camera
#    one row per intersection
# camera_coverage
#    a single shape containing 120m balls around each camera location
# camera_count
#    one row per census tract, giving the number of cameras by several different counting methods




#---------------------------------------
# A list of the five boroughs of NYC. These will be used to filter various of the other datasets,
# which would otherwise include all of New York state.

COUNTY <- fread(colClasses='character', text='
borough, county, countyfp
Bronx, "Bronx County", "005"
Brooklyn, "Kings County", "047"
Manhattan, "New York County", "061"
Queens, "Queens County", "081"
"Staten Island", "Richmond County", "085"
')
COUNTY[, fips := paste0('36', countyfp)]



#---------------------------------------
# Census tracts as of 2019, from the US Census.
# TRACTS contains the full official tracts,
# tracts contains the tracts clipped to the shoreline
# (and thus tracts excludes two TRACTS that are entirely aquatic)

BOROUGH <- st_read('data/nyc/shoreline/Counties_Shoreline.shp', quiet=TRUE)
BOROUGH <- BOROUGH[BOROUGH$FIPS_CODE %in% COUNTY$fips,]
BOROUGH <- st_transform(BOROUGH, crs='epsg:2908')
SHORELINE <- st_union(BOROUGH)

TRACTS <- st_read('data/census/tracts/tl_2019_36_tract.shp', quiet=TRUE)
TRACTS <- TRACTS[TRACTS$COUNTYFP %in% COUNTY$countyfp,]
st_agr(TRACTS) <- 'constant'
TRACTS <- st_transform(TRACTS, crs='epsg:2908')
tracts <- st_intersection(TRACTS, SHORELINE)
tracts$fips <- substr(tracts$GEOID,1,5)
tracts <- merge(tracts, COUNTY[, list(fips,borough)], by='fips', all.x=TRUE)

# There are two census tracts that are entirely aquatic,
# GEOID %in% c('36047990100','36081990100')
# We'll remove these from the census dataframe, since they're not relevant to this analysis
aquatic_tracts <- setdiff(TRACTS$GEOID, tracts$GEOID)

#options(repr.plot.width=7, repr.plot.height=5)
#ggplot() +
#  geom_sf(data=TRACTS[TRACTS$GEOID %in% aquatic_tracts,], fill='lightblue') +
#  geom_sf(data=SHORELINE, fill=NA)



#---------------------------------------
# ACS 2014--2019 data, from the census.
# We'll discard the two entirely aquatic tracts.

CENSUS <- get_acs(geography='tract', state='NY', county=COUNTY$county, 
                  year=2019,
                  variables=c(med.income="B19013_001", 
                              popn='B01003_001', popn.white='B02001_002', popn.black='B02001_003', popn.asian='B02001_005', popn.hispanic='B03001_003',
                              popn.male='B01001_002', popn.female='B01001_026')
                 )

census <- dcast(GEOID+NAME ~ variable, data=as.data.table(CENSUS), value.var='estimate')
census <- census[!(GEOID %in% aquatic_tracts)]



#---------------------------------------
# Stop-and-frisk data, from NYPD.
# Transform the coordinates to NewYork-LongIsland State Plane coordinate system (units: feet)
# I can't find a specification of the coordinate system used here. I'll assume it's epsg 2908,
# since that's consistent with the data provided by Amnesty (filename sqf-2019-latlng.csv), and
# following another reference: https://scholarworks.calstate.edu/downloads/2z10ws18s?locale=es

# There are 7 stops that fall outside the five boroughs.
# For four of them, the geocoding is nonsense, so we'll remove them.
# For the other three, map them to the nearest tract.

SQF2019 <- read_excel('data/nyc/sqf-2019.xlsx')
SQF2020 <- read_excel('data/nyc/sqf-2020.xlsx')
names(SQF2019)[names(SQF2019)=='STOP_ID_ANONY'] <- 'STOP_ID' # this is the only difference in columns
sqf <- rbind(SQF2019, SQF2020)
sqf$YEAR2 <- as.integer(sqf$YEAR2) # year should be integer, not double!
sqf$STOP_ID <- paste(sqf$YEAR2, sqf$STOP_ID, sep='.')
# Discard the known-bad stops.
sqf <- sqf[!(sqf$STOP_ID %in% c('2020.4986','2020.5566','2020.8826','2020.8875')),]

sqf <- st_as_sf(sqf, coords=c('STOP_LOCATION_X','STOP_LOCATION_Y'), crs='epsg:2908', remove=FALSE)
sqf <- st_join(sqf, TRACTS[,'GEOID'], left=TRUE)

# Sanity checks: no stop should be in more than one tract, and every stop should be in a tract
stopifnot(!duplicated(as.data.table(sqf)[, list(STOP_ID,YEAR2)]))
nogeoid <- which(is.na(sqf$GEOID))
if (length(nogeoid)>0) warning("Assigning ", length(nogeoid)," stops to nearest tract")
sqf$GEOID[nogeoid] <- tracts$GEOID[apply(st_distance(sqf[is.na(sqf$GEOID),], TRACTS), 1, which.min)]




#---------------------------------------
# Camera locations, provided by Amnesty volunteer effort.
# ASSUMPTION: only the cameras attached to street poles are "public" cameras,
# and the others are private. This analysis will only look at public cameras.

CAMERA <- fread('GIVEN/decoder/counts_per_intersections.csv')
PANORAMA <- fread('GIVEN/decoder/panorama_url.csv')
camera <- merge(CAMERA, PANORAMA[, list(PanoramaId,GoogleLat,GoogleLong)], by='PanoramaId', all.x=TRUE)
camera[, public := attached_street_median > 0]
camera <- st_as_sf(camera, coords=c('GoogleLong','GoogleLat'), crs='epsg:4326')
camera <- st_transform(camera, crs='epsg:2908')



# camera_coverage: a 120m-radius blob around every camera, unioned together
# (This figure of 120m is what's used by the interactive graphic. It should be used here for consistency.)

# In this analysis, I'll count camera coverage in terms of "effective cameras",
# defined as area_surveilled / π*(120m)^2. If two cameras are very close to each other,
# it's presumably because there's a problem with sightlines, so really the coverage
# is the same as just a single camera with clear sightlines.

CAMERA_RADIUS <- set_units(120,'m')
CAMERA_AREA <- pi * CAMERA_RADIUS^2
camera_coverage <- st_union(st_buffer(camera[camera$public,], dist=CAMERA_RADIUS))



# camera_count, the number of cameras in each tract
# There are several ways we might count this ...

# Effective number of cameras inside the census tract
df <- tracts[,'GEOID']
st_agr(df) <- 'constant' # so we don't get silly warning about 'attribute assumed spatially constant'
df0 <- st_intersection(df, camera_coverage)
df0$eff_cameras <- as.numeric(st_area(df0) / CAMERA_AREA)

# Effective number of cameras within 200m of the census tract
df1 <- st_buffer(df, set_units(200,'m'))
df1 <- st_intersection(df1, camera_coverage)
df1$eff_cameras_within_200m <- as.numeric(st_area(df1) / CAMERA_AREA)

# Raw count of number of public cameras within 200m of the TRACT
# (There are a handful that fall outside a TRACT, which are discarded by this join.)
df2 <- st_join(camera[camera$public,], st_buffer(TRACTS[,'GEOID'], set_units(200,'m')))

# Raw count of number of public cameras within the TRACT
df3 <- st_join(camera[camera$public,], TRACTS[,'GEOID'])

# Merge these various counts, and also merge in the full list of tracts
camera_count <- merge(as.data.table(st_drop_geometry(df1))[, list(GEOID, eff_cameras_within_200m)],
                      as.data.table(st_drop_geometry(df0))[, list(GEOID, eff_cameras)],
                      by='GEOID', all=TRUE)
camera_count <- merge(camera_count,
                      as.data.table(st_drop_geometry(df2))[, list(cameras_within_200m=sum(attached_street_median)), by=GEOID],
                      by='GEOID', all=TRUE)
camera_count <- merge(camera_count,
                      as.data.table(st_drop_geometry(df3))[, list(cameras=sum(attached_street_median)), by=GEOID],
                      by='GEOID', all=TRUE)
camera_count[is.na(eff_cameras), eff_cameras := 0]
camera_count[is.na(cameras_within_200m), cameras_within_200m := 0]
camera_count[is.na(cameras), cameras := 0]
empty_tracts <- setdiff(tracts$GEOID, camera_count$GEOID)
camera_count <- rbind(camera_count, data.table(GEOID=empty_tracts, eff_cameras=0, eff_cameras_within_200m=0, cameras_within_200m=0, cameras=0))
