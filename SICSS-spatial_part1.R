#' ---
#' title: "Part 1: Using and linking spatial data"
#' author: "Tobias Rüttenauer"
#' date: "July 02, 2022"
#' output_dir: docs
#' output: 
#'   html_document:
#'     theme: flatly
#'     highlight: haddock
#'     toc: true
#'     toc_float:
#'       collapsed: false
#'       smooth_scroll: false
#'     toc_depth: 2
#' theme: united
#' bibliography: sicss-spatial.bib
#' link-citations: yes
#' ---
#' 
#' ### Required packages
#' 
## ---- message = FALSE, warning = FALSE, results = 'hide'----------------------------------------
pkgs <- c("sf", "gstat", "mapview", "nngeo", "rnaturalearth", "dplyr",
          "nomisr", "osmdata", "tidyr", "texreg") 
lapply(pkgs, require, character.only = TRUE)


#' 
#' ### Session info
#' 
## -----------------------------------------------------------------------------------------------
sessionInfo()


#' 
#' # Coordinates
#' 
#' In general, spatial data is structured like conventional data (e.g. data.frames, matrices), but has one additional dimension: every observation is linked to some sort of geo-spatial information. Most common types of spatial information are:
#' 
#' * Points (one coordinate pair)
#' 
#' * Lines (two coordinate pairs)
#' 
#' * Polygons (at least three coordinate pairs)
#' 
#' * Regular grids (one coordinate pair for centroid + raster / grid size)
#' 
#' 
#' ## Coordinate reference system (CRS)
#' 
#' In its raw form, a pair of coordinates consists of two numerical values. For instance, the pair `c(51.752595, -1.262801)` describes the location of Nuffield College in Oxford (one point). The fist number represents the latitude (north-south direction), the second number is the longitude (west-east direction), both are in decimal degrees.
#' 
#' ![Figure: Latitude and longitude, Source: [Wikipedia](https://en.wikipedia.org/wiki/Geographic_coordinate_system)](fig/lat-long.png)
#' 
#' However, we need to specify a reference point for latitudes and longitudes (in the Figure above: equator and Greenwich). For instance, the pair of coordinates above comes from Google Maps which returns GPS coordinates in 'WGS 84' ([EPSG:4326](https://epsg.io/4326)). 
#' 
## -----------------------------------------------------------------------------------------------
# Coordinate pairs of two locations
coords1 <- c(51.752595, -1.262801)
coords2 <- c(51.753237, -1.253904)
coords <- rbind(coords1, coords2)

# Conventional data frame
nuffield.df <- data.frame(name = c("Nuffield College", "Radcliffe Camera"),
                          address = c("New Road", "Radcliffe Sq"),
                          lat = coords[,1], lon = coords[,2])

head(nuffield.df)

# Combine to spatial data frame
nuffield.spdf <- st_as_sf(nuffield.df, 
                          coords = c("lon", "lat"), # Order is important
                          crs = 4326) # EPSG number of CRS

# Map
mapview(nuffield.spdf, zcol = "name")


#' 
#' ## Projected CRS
#' 
#' However, different data providers use different CRS. For instance, spatial data in the UK usually uses 'OSGB 1936 / British National Grid' ([EPSG:27700](https://epsg.io/27700)). Here, coordinates are in meters, and projected onto a planar 2D space. 
#' 
#' There are a lot of different CRS projections, and different national statistics offices provide data in different projections. Data providers usually specify which reference system they use. This is important as using the correct reference system and projection is crucial for plotting and manipulating spatial data. 
#' 
#' If you do not know the correct CRS, try starting with a standards CRS like [EPSG:4326](https://epsg.io/4326) if you have decimal degree like coordinates. If it looks like projected coordinates, try searching for the country or region in CRS libraries like https://epsg.io/. However, you must check if the projected coordinates match their real location, e.g. using `mpaview()`.
#' 
#' ## Why different projections?
#' 
#' By now, (most) people agree that [the earth is not flat](https://r-spatial.org/r/2020/06/17/s2.html). So, to plot data on a 2D planar surface and to perform certain operations on a planar world, we need to make some re-projections. Depending on where we are, different re-projections of our data might work better than others.
#' 
## -----------------------------------------------------------------------------------------------
world <- ne_countries(scale = "medium", returnclass = "sf")
class(world)
st_crs(world)

# Extract a country and plot in current CRS (WGS84)
ger.spdf <- world[world$name == "Germany", ]
plot(st_geometry(ger.spdf))

# Now, lets transform Germany into a CRS optimized for Iceland
ger_rep.spdf <- st_transform(ger.spdf, crs = 5325)
plot(st_geometry(ger_rep.spdf))


#' 
#' Depending on the angle, a 2D projection of the earth looks different. It is important to choose a suitable projection for the available spatial data. For more information on CRS and re-projection, see e.g. @Lovelace.2019.
#' 
#' 
#' # Importing some real word data
#' 
#' `sf` imports many of the most common spatial data files, like geojson, gpkg, or shp. 
#' 
#' ## London shapefile (polygon)
#' 
#' Lets get some administrative boundaries for London from the [London Datastore](https://data.london.gov.uk/dataset/statistical-gis-boundary-files-london). 
## -----------------------------------------------------------------------------------------------
# Create subdir 
dn <- "_data"
ifelse(dir.exists(dn), "Exists", dir.create(dn))

# Download zip file and unzip
tmpf <- tempfile()
boundary.link <- "https://data.london.gov.uk/download/statistical-gis-boundary-files-london/9ba8c833-6370-4b11-abdc-314aa020d5e0/statistical-gis-boundaries-london.zip"
download.file(boundary.link, tmpf)
unzip(zipfile = tmpf, exdir = paste0(dn))
unlink(tmpf)

# This is a shapefile
# We only need the MSOA layer for now
msoa.spdf <- st_read(dsn = paste0(dn, "/statistical-gis-boundaries-london/ESRI"),
                     layer = "MSOA_2011_London_gen_MHW" # Note: no file ending
                     )
head(msoa.spdf)

# Similarly you can read geo.json (usually more efficient, but less common)
# Download file
ulez.link <- "https://data.london.gov.uk/download/ultra_low_emissions_zone/3d980a29-c340-4892-8230-ed40d8c7f32d/Ultra_Low_Emissions_Zone.json"
download.file(ulez.link, paste0(dn, "/ulez.json"))

# Read geo.json
st_layers(paste0(dn, "/ulez.json"))
ulez.spdf <- st_read(dsn = paste0(dn, "/ulez.json")) # here dsn is simply the file
head(ulez.spdf)




#' 
#' This looks like a conventional `data.frame` but has the additional column `geometry` containing the coordinates of each observation. `st_geometry()` returns only the geographic object and `st_drop_geometry()` only the `data.frame` without the coordinates. We can plot the object using `mapview()`.
#' 
## -----------------------------------------------------------------------------------------------
mapview(msoa.spdf[, "POPDEN"])


#' 
#' ## Census API (admin units)
#' 
#' Now that we have some boundaries and shapes of spatial units in London, we can start looking for different data sources to populate the geometries.
#' 
#' A good source for demographic data is for instance the 2011 census. Below we use the nomis API to retrieve population data for London, See the [Vignette](https://cran.r-project.org/web/packages/nomisr/vignettes/introduction.html) for more information (Guest users are limited to 25,000 rows per query). Below is a wrapper to avoid some mess with sex and urban-rural cross-tabs.
#' 
## -----------------------------------------------------------------------------------------------
### For larger request, register and set key
# Sys.setenv(NOMIS_API_KEY = "XXX")
# nomis_api_key(check_env = TRUE)

x <- nomis_data_info()

# Get London ids
london_ids <- msoa.spdf$MSOA11CD

### Get key statistics ids
# select requires tables (https://www.nomisweb.co.uk/sources/census_2011_ks)
# Let's get KS201EW (ethnic group) and KS402EW (housing tenure)

# Get internal ids
stats <- c("KS201EW", "KS402EW")
oo <- which(grepl(paste(stats, collapse = "|"), x$name.value))
ksids <- x$id[oo]
ksids # This are the internal ids


### look at meta information
q <- nomis_overview(ksids[1])
head(q)
a <- nomis_get_metadata(id = ksids[1], concept = "GEOGRAPHY", type = "type")
a # TYPE297 is MSOA level

b <- nomis_get_metadata(id = ksids[1], concept = "MEASURES", type = "TYPE297")
b # 20100 is the measure of absolute numbers


### Query data in loop over the required statistics
for(i in ksids){

  # Determin if data is divided by sex or urban-rural
  nd <- nomis_get_metadata(id = i)
  if("RURAL_URBAN" %in% nd$conceptref){
    UR <- TRUE
  }else{
    UR <- FALSE
  }
  if("C_SEX" %in% nd$conceptref){
    SEX <- TRUE
  }else{
    SEX <- FALSE
  }

  # make data request
  if(UR == TRUE){
    if(SEX == TRUE){
      tmp_en <- nomis_get_data(id = i, time = "2011", 
                               geography = london_ids, # replace with "TYPE297" for all MSOAs
                               measures = 20100, RURAL_URBAN = 0, C_SEX = 0)
    }else{
      tmp_en <- nomis_get_data(id = i, time = "2011", 
                               geography = london_ids, # replace with "TYPE297" for all MSOAs
                               measures = 20100, RURAL_URBAN = 0)
    }
  }else{
    if(SEX == TRUE){
      tmp_en <- nomis_get_data(id = i, time = "2011", 
                               geography = london_ids, # replace with "TYPE297" for all MSOAs
                               measures = 20100, C_SEX = 0)
    }else{
      tmp_en <- nomis_get_data(id = i, time = "2011", 
                               geography = london_ids, # replace with "TYPE297" for all MSOAs
                               measures = 20100)
    }

  }

  # Append (in case of different regions)
  ks_tmp <- tmp_en

  # Make lower case names
  names(ks_tmp) <- tolower(names(ks_tmp))
  names(ks_tmp)[names(ks_tmp) == "geography_code"] <- "msoa11"
  names(ks_tmp)[names(ks_tmp) == "geography_name"] <- "name"

  # replace weird cell codes
  onlynum <- which(grepl("^[[:digit:]]+$", ks_tmp$cell_code))
  if(length(onlynum) != 0){
    code <- substr(ks_tmp$cell_code[-onlynum][1], 1, 7)
    if(is.na(code)){
      code <- i
    }
    ks_tmp$cell_code[onlynum] <- paste0(code, "_", ks_tmp$cell_code[onlynum])
  }

  # save codebook
  ks_cb <- unique(ks_tmp[, c("date", "cell_type", "cell", "cell_code", "cell_name")])

  ### Reshape
  ks_res <- tidyr::pivot_wider(ks_tmp, id_cols = c("msoa11", "name"),
                               names_from = "cell_code",
                               values_from = "obs_value")

  ### Merge
  if(i == ksids[1]){
    census_keystat.df <- ks_res
    census_keystat_cb.df <- ks_cb
  }else{
    census_keystat.df <- merge(census_keystat.df, ks_res, by = c("msoa11", "name"), all = TRUE)
    census_keystat_cb.df <- rbind(census_keystat_cb.df, ks_cb)
  }

}


# Descirption are saved in the codebook
head(census_keystat_cb.df)

### Merge with MSOA geometries above
msoa.spdf <- merge(msoa.spdf, census_keystat.df, 
                   by.x = "MSOA11CD", by.y = "msoa11", all.x = TRUE)


#' 
#' Now we can, for instance, plot the spatial distribution of ethnic groups.
#' 
## -----------------------------------------------------------------------------------------------

msoa.spdf$per_white <- msoa.spdf$KS201EW_100 / msoa.spdf$KS201EW0001 * 100

mapview(msoa.spdf[, "per_white"])


#' 
#' ## Gridded data
#' 
#' So far, we have queried data on adminstrative units. However, often data comes on other spatial scales. For instance, we might be interested in the amount of air pollution, which is provided on a regular grid across the UK from [Defra](https://uk-air.defra.gov.uk/data/pcm-data).
#' 
## -----------------------------------------------------------------------------------------------
# Download
pol.link <- "https://uk-air.defra.gov.uk/datastore/pcm/mapno22011.csv"
download.file(pol.link, paste0(dn, "/mapno22011.csv"))
pol.df <- read.csv(paste0(dn, "/mapno22011.csv"), skip = 5, header = T, sep = ",",
                      stringsAsFactors = F, na.strings = "MISSING")

head(pol.df)

# The data comes as point data with x and y as coordinates. 
# We have to transform this into spatial data first.
pol.spdf <- st_as_sf(pol.df, coords = c("x", "y"),
                    crs = 27700)

# Subsequently, we transform the point coordinates into a regular grid with "diameter" 500m
pol.spdf <- st_buffer(pol.spdf, dist = 500, nQuadSegs  = 1, 
                      endCapStyle = 'SQUARE')

# Plot NO2
plot(pol.spdf[, "no22011"], border = NA)

#' 
#' 
#' 
#' ## OpenStreetMap (points)
#' 
#' Another interesting data source is the OpenStreetMap API, which provides information about the geographical location of a serious of different indicators. Robin Lovelace provides a nice introduction to the [osmdata API](https://cran.r-project.org/web/packages/osmdata/vignettes/osmdata.html). Available features can be found on [OSM wiki](https://wiki.openstreetmap.org/wiki/Map_features).
#' 
#' 
## -----------------------------------------------------------------------------------------------
# First we create a bounding box of where we want to query data
# st_bbox() can be used to get bounding boxes of an existing spatial object (needs CRS = 4326)
# q <- opq(bbox = 'greater london uk')
q <- opq(bbox = st_bbox(st_transform(msoa.spdf, 4326)))

# Lets get the location of pubs in London
osmq <- add_osm_feature(q, key = "amenity", value = c("pub", "bar"))

# Query
pubs.osm <- osmdata_sf(osmq)

# Right now there are some results in polygons, some in points, and they overlap
# Make unique points / polygons 
pubs.osm <- unique_osmdata(pubs.osm)

# Get points and polygons (there are barly any pubs as polygons, so we ignore for now)
pubs.points <- pubs.osm$osm_points
pubs.polys <- pubs.osm$osm_multipolygons

mapview(pubs.points)

# Drop OSM file
rm(pubs.osm); gc()

# Reduce to point object only 
pubs.spdf <- pubs.points



#' 
#' Note that OSM is solely based on contribution by users, and the __quality of OSM data varies__. Usually data quality is better in larger cities, adn better for more stable features (such as hospitals, train stations, highways). However, data from [London Datastore](https://data.london.gov.uk/dataset/cultural-infrastructure-map) would indicate more pubs than what we find with OSM.
#' 
#' 
#' 
#' 
#' 
#' # Manipulation and linkage
#' 
#' Having data with geo-spatial information allows to perform a variety of methods to manipulate and link different data sources. Commonly used methods include 1) subsetting, 2) point-in-polygon operations, 3) distance measures, 4) intersections or buffer methods.
#' 
#' The [online Vignettes of the sf package](https://r-spatial.github.io/sf/articles/) provide a comprehensive overview of the multiple ways of spatial manipulations.
#' 
#' 
#' #### Check if data is on common projection
#' 
## -----------------------------------------------------------------------------------------------
st_crs(msoa.spdf) == st_crs(pol.spdf)
st_crs(msoa.spdf) == st_crs(pubs.spdf)
st_crs(msoa.spdf) == st_crs(ulez.spdf)


# MSOA in different crs --> transform
pol.spdf <- st_transform(pol.spdf, crs = st_crs(msoa.spdf))
pubs.spdf <- st_transform(pubs.spdf, crs = st_crs(msoa.spdf))
ulez.spdf <- st_transform(ulez.spdf, crs = st_crs(msoa.spdf))


# Check if all geometries are valid, and make valid if needed
msoa.spdf <- st_make_valid(msoa.spdf)


#' 
#' ## Subsetting
#' 
#' We can subset spatial data in a similar way as we subset conventional data.frames or matrices. For instance, below we simply reduce the pollution grid across the UK to observations in London only.
#' 
## -----------------------------------------------------------------------------------------------

# Subset to pollution estimates in London
pol_sub.spdf <- pol.spdf[msoa.spdf, ] # or:
pol_sub.spdf <- st_filter(pol.spdf, msoa.spdf)
mapview(pol_sub.spdf)


#' 
#' Or we can reverse the above and exclude all intersecting units by specifying `st_disjoint` as alternative spatial operation using the `op =` option (note the empty space for column selection). `st_filter()` with the `.predicate` option does the same job. See the [sf Vignette](https://cran.r-project.org/web/packages/sf/vignettes/sf3.html) for more operations.
#' 
## -----------------------------------------------------------------------------------------------
# Subset pubs to pubs not in the ulez area
sub2.spdf <- pubs.spdf[ulez.spdf, , op = st_disjoint] # or:
sub2.spdf <- st_filter(pubs.spdf, ulez.spdf, .predicate = st_disjoint)
mapview(sub2.spdf)

# We can easily create indicators of whether an MSOA is within ulez or not
msoa.spdf$ulez <- 0
within <- msoa.spdf[ulez.spdf,]
msoa.spdf$ulez[which(msoa.spdf$MSOA11CD %in% within$MSOA11CD)] <- 1
table(msoa.spdf$ulez)


#' 
#' ## Point in polygon
#' 
#' We are interested in the number of pubs in each MSOA. So, we count the number of points in each polygon.
#' 
## -----------------------------------------------------------------------------------------------
# Assign MSOA to each point
pubs_msoa.join <- st_join(pubs.spdf, msoa.spdf, join = st_within)

# Count N by MSOA code (drop geometry to speed up)
pubs_msoa.join <- dplyr::count(st_drop_geometry(pubs_msoa.join),
                               MSOA11CD = pubs_msoa.join$MSOA11CD,
                               name = "pubs_count")
sum(pubs_msoa.join$pubs_count)

# Merge and replace NAs with zero (no matches, no pubs)
msoa.spdf <- merge(msoa.spdf, pubs_msoa.join,
                   by = "MSOA11CD", all.x = TRUE)
msoa.spdf$pubs_count[is.na(msoa.spdf$pubs_count)] <- 0


#' 
#' ## Distance measures
#' 
#' We might be interested in the distance to the nearest pub. Here, we use the package `nngeo` to find k nearest neighbours with the respective distance.
#' 
## -----------------------------------------------------------------------------------------------
# Use geometric centroid of each MSOA
cent.sp <- st_centroid(msoa.spdf[, "MSOA11CD"])

# Get K nearest neighbour with distance
knb.dist <- st_nn(cent.sp, pubs.spdf,
                  k = 1, returnDist = TRUE,
                  progress = FALSE)
msoa.spdf$dist_pubs <- unlist(knb.dist$dist)
summary(msoa.spdf$dist_pubs)


#' 
#' 
#' ## Intersections + Buffers
#' 
#' We might also be interested in the average tree cover density within 1 km radius around each MSOA centroid. Therefore, we first create a buffer with `st_buffer()` around each midpoint and subsequently use `st_intersetion()` to calculate the overlap.
#' 
## -----------------------------------------------------------------------------------------------
# Create buffer (1km radius)
cent.buf <- st_buffer(cent.sp, dist = 1000)
mapview(cent.buf)

# Add area of each buffer (in this constant) 
cent.buf$area <- as.numeric(st_area(cent.buf))

# Calculate intersection of pollution grid and buffer
int.df <- st_intersection(cent.buf, pol.spdf)
int.df$int_area <- as.numeric(st_area(int.df)) # area of intersection

# Area of intersection as share of buffer
int.df$area_per <- int.df$int_area / int.df$area

# Aggregate as weighted mean
int.df <- st_drop_geometry(int.df)
int.df$no2_weighted <- int.df$no22011 * int.df$area_per
int.df <- aggregate(list(no2 = int.df[, "no2_weighted"]), 
                    by = list(MSOA11CD = int.df$MSOA11CD),
                    sum)

# Merge back to spatial data.frame
msoa.spdf <- merge(msoa.spdf, int.df, by = "MSOA11CD", all.x = TRUE)

mapview(msoa.spdf[, "no2"])


#' 
#' Note: for buffer related methods, it often makes sense to use population weighted centroids instead of geographic centroids (see [here](https://geoportal.statistics.gov.uk/datasets/ons::middle-layer-super-output-areas-december-2011-population-weighted-centroids/about) for MSOA population weighted centroids). However, often this information is not available.
#' 
#' 
#' 
#' 
#' ### Air pollution and ethnic minorities
#' 
#' With a few lines of code, we have compiled an original dataset containing demographic information, air pollution, and some infrastructural information. 
#' 
#' Let's see what we can do with it.
#' 
## -----------------------------------------------------------------------------------------------
# Define ethnic group shares
msoa.spdf$per_mixed <- msoa.spdf$KS201EW_200 / msoa.spdf$KS201EW0001 * 100
msoa.spdf$per_asian <- msoa.spdf$KS201EW_300 / msoa.spdf$KS201EW0001 * 100
msoa.spdf$per_black <- msoa.spdf$KS201EW_400 / msoa.spdf$KS201EW0001 * 100
msoa.spdf$per_other <- msoa.spdf$KS201EW_500 / msoa.spdf$KS201EW0001 * 100

# Define tenure
msoa.spdf$per_owner <- msoa.spdf$KS402EW_100 / msoa.spdf$KS402EW0001 * 100
msoa.spdf$per_social <- msoa.spdf$KS402EW_200 / msoa.spdf$KS402EW0001 * 100


# Run regression
mod1.lm <- lm(no2 ~ per_mixed + per_asian + per_black + per_other +
                per_owner + per_social + pubs_count + POPDEN + ulez,
              data = msoa.spdf)

# summary
screenreg(list(mod1.lm), digits = 3)


#' 
#' 
#' ### Save spatial data
#' 
## -----------------------------------------------------------------------------------------------
# Save
save(msoa.spdf, file = "_data/msoa_spatial.RData")
save(ulez.spdf, file = "_data/ulez_spatial.RData")



#' 
#' 
#' 
#' 
#' # Interpolation and Kriging
#' 
#' For (sparse) point data, we the nearest count point often might be far away from where we want to measure or merge its attributes. A potential solution is to spatially interpolate the data (e.g. on a regular grid): given a specific function of space (and covariates), we make prediction about an attribute at "missing" locations. For more details, see, for instance, [Spatial Data Science](https://keen-swartz-3146c4.netlify.app/interpolation.html) or [Introduction to Spatial Data Programming with R](https://keen-swartz-3146c4.netlify.app/interpolation.html).
#' 
#' First lets get some point data with associated attributes or measures. In this example, we use traffic counts provided by the [Department for Transport](https://roadtraffic.dft.gov.uk/regions/6).
#' 
#' 
#' 
## -----------------------------------------------------------------------------------------------
# Download traffic
traffic.link <- "https://storage.googleapis.com/dft-statistics/road-traffic/downloads/aadf/region_id/dft_aadf_region_id_6.csv"
download.file(traffic.link, paste0(dn, "/traffic.csv"))

# Read and select major roads only
traffic.df <- read.csv(paste0(dn, "/traffic.csv"))
traffic.df <- traffic.df[which(traffic.df$year == 2011 &
                       traffic.df$road_type == "Major"), ]
names(traffic.df)

# Transform to spatial data
traffic.spdf <- st_as_sf(traffic.df,
                         coords = c("longitude", "latitude"),
                         crs = 4326)

# Transform into common crs
traffic.spdf <- st_transform(traffic.spdf,
                             crs = st_crs(msoa.spdf))

# Map
mapview(traffic.spdf[, "all_motor_vehicles"])

# Save (for later exercise)
save(traffic.spdf, file = "_data/traffic.RData")


#' 
#' To interpolate, we first create a grid surface over London on which we make predictions.
#' 
## -----------------------------------------------------------------------------------------------
# Set up regular grid over London with 1km cell size
london.sp <- st_union(st_geometry(msoa.spdf))
grid <- st_make_grid(london.sp, cellsize = 1000)
mapview(grid)

# Reduce to London bounds
grid <- grid[london.sp]
mapview(grid)



#' 
#' There are various ways of interpolating. Common methods are nearest neighbours matching or inverse distance weighted interpolation (using `idw()`): each value at a given point is a weighted average of surrounding values, where weights are a function of distance.
#' 
## -----------------------------------------------------------------------------------------------
# IDW interpolation
all_motor.idw <- idw(all_motor_vehicles ~ 1,
                     locations = traffic.spdf,
                     newdata = grid,
                     idp = 2) # power of distance decay
mapview(all_motor.idw[, "var1.pred"])

#' 
#' IDW is a fairly simple way of interpolation and it assumes a deterministic form of spatial dependence.
#' 
#' Another technique is Kriging, which estimates values as a function of a deterministic trend and a random process. However, we have to set some hyper-parameters for that: sill, range, nugget, and the functional form. Therefore, we first need to fit a semi-variogram. Subsequently, we let the `fit.variogram()` function chose the parameters based on the empirical variogram [see for instance [r-spatial Homepage](https://r-spatial.org/r/2016/02/14/gstat-variogram-fitting.html)].
#' 
#' 
## -----------------------------------------------------------------------------------------------
# Variogram
all_motor.var <- variogram(all_motor_vehicles ~ 1,
                          traffic.spdf)
plot(all_motor.var)

# Fit variogram
all_motor.varfit <- fit.variogram(all_motor.var,
                                  vgm(c("Nug", "Exp")), # use vgm() to see options
                                  fit.kappa = TRUE, fit.sills = TRUE, fit.ranges = TRUE)

plot(all_motor.var, all_motor.varfit)

# Parameters
all_motor.varfit


### Ordinary Kriging 
#(ATTENTION: This can take some time (~3min with current setting))

all_motor.kg <- krige(all_motor_vehicles ~ 1,
                      locations = traffic.spdf,
                      newdata = grid,
                      model = all_motor.varfit)

# Look at results
mapview(all_motor.kg[, "var1.pred"])


#' 
#' The example above is a little bit tricky, given that traffic does not follow a random process, but (usually) follows the street network. We would probably increase the performance by either adding the street network (e.g. using [osmdata](https://cran.r-project.org/web/packages/osmdata/vignettes/osmdata.html) OSM Overpass API) and interpolating along this network, or by adding covariates to our prediction (Universal Kriging). With origin - destination data, we could use [stplanr](https://cran.r-project.org/web/packages/stplanr/vignettes/stplanr-od.html) for routing along the street network.
#' 
#' Alternatively, we can use integrated nested Laplace approximation with [R-INLA](https://becarioprecario.bitbucket.io/inla-gitbook/index.html) [@GomezRubio.2020].
#' 
#' However, lets add the predictions to our original msoa data using the `st_intersection()` operation as above.
#' 
#' 
## -----------------------------------------------------------------------------------------------
# Calculate intersection
smoa_grid.int <- st_intersection(msoa.spdf, all_motor.kg)

# average per MSOA
smoa_grid.int <- aggregate(list(traffic = smoa_grid.int$var1.pred),
                         by = list(MSOA11CD = smoa_grid.int$MSOA11CD),
                         mean)

# Merge back
msoa.spdf <- merge(msoa.spdf, smoa_grid.int, by = "MSOA11CD", all.x = TRUE)


#' 
#' 
#' 
#' 
#' # References
