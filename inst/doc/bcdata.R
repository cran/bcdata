## ----setup, include = FALSE----------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  warning = FALSE,
  message = FALSE
)

library(bcdata)
library(ggplot2)

## ---- eval=FALSE---------------------------------------------------------
#  install.packages("remotes")
#  
#  remotes::install_github("bcgov/bcdata")
#  library(bcdata)

## ---- eval=FALSE---------------------------------------------------------
#  ## Take me to the B.C. Data Catalogue home page
#  bcdc_browse()

## ---- eval=FALSE---------------------------------------------------------
#  ## Take me to the B.C. Winery Locations catalogue record using the record name
#  bcdc_browse("bc-winery-locations")
#  
#  ## Take me to the B.C. Winery Locations catalogue record using the record ID
#  bcdc_browse("1d21922b-ec4f-42e5-8f6b-bf320a286157")

## ---- eval=FALSE---------------------------------------------------------
#  ## Take me to the catalogue search results for 'wineries'
#  bcdc_browse("wineries")

## ------------------------------------------------------------------------
## Give me the catalogue search results for 'recycling'
bcdc_search("recycling")

## ------------------------------------------------------------------------
## Give me the first catalogue search result for 'recycling'
bcdc_search("recycling", n = 1)

## Give me the catalogue search results for 'recycling' where the 
## data is tabular and licenced under Open Government Licence – British Columbia
bcdc_search("recycling", type = "Dataset", license_id = "2")

## ------------------------------------------------------------------------
## Valid values for search facet 'license_id'
bcdc_search_facets(facet = "license_id")

## ------------------------------------------------------------------------
## Give me the catalogue record metadata for `bc-first-tire-recycling-data-1991-2006`
bcdc_get_record("a29ad492-29a2-44b9-8693-d27a8cc8e686")

## ------------------------------------------------------------------------
## Get the data resource for the `bc-highway-cams` catalogue record
bcdc_get_data("bc-highway-cams") 

## OR use the permanent ID, which is better for scripts or non-interactive use 
bcdc_get_data("6b39a910-6c77-476f-ac96-7b4f18849b1c")

## OR use the result from bcdc_get_record()
my_data <- bcdc_get_record("6b39a910-6c77-476f-ac96-7b4f18849b1c")
bcdc_get_data(my_data)

## ------------------------------------------------------------------------
## Get the record ID for the `bc-schools-programs-offered-in-schools` catalogue record
bcdc_search("school programs", n = 1)

## Get the metadata for the `bc-schools-programs-offered-in-schools` catalogue record
bcdc_get_record("b1f27d1c-244a-410e-a361-931fac62a524")

## ------------------------------------------------------------------------
## Get the txt data resource from the `bc-schools-programs-offered-in-schools`
## catalogue record
bcdc_get_data("b1f27d1c-244a-410e-a361-931fac62a524", resource = 'a393f8cf-51ec-42c6-8449-4cea4c75385c')

## ---- fig.height = 5, fig.width = 7--------------------------------------
## Find the B.C. Air Zones catalogue record
bcdc_search("air zones", res_format = "geojson")

## Get the metadata for the B.C. Air Zones catalogue record
bc_az_metadata <- bcdc_get_record("e8eeefc4-2826-47bc-8430-85703d328516")

## Get the B.C. Air Zone geospatial data
bc_az <- bcdc_get_data(bc_az_metadata, resource = "c495d082-b586-4df0-9e06-bd6b66a8acd9")

## Plot the B.C. Air Zone geospatial data with ggplot()
bc_az %>% 
  ggplot() +
  geom_sf()

## ------------------------------------------------------------------------
bcdc_get_data("WHSE_IMAGERY_AND_BASE_MAPS.GSR_AIRPORTS_SVW")

## ---- fig.height = 5, fig.width = 7--------------------------------------
## Find the B.C. Regional Districts catalogue record
bcdc_search("regional districts administrative areas", res_format = "wms", n = 1)

## Get the metadata for the B.C. Regional Districts catalogue record
bc_regional_districts_metadata <- bcdc_get_record("d1aff64e-dbfe-45a6-af97-582b7f6418b9")

## Have a quick look at the geospatial columns to help with filter or select
bcdc_describe_feature(bc_regional_districts_metadata)

## Get the Capital Regional District polygon from the B.C. Regional 
## Districts geospatial data
my_regional_district <- bcdc_query_geodata(bc_regional_districts_metadata) %>% 
  filter(ADMIN_AREA_NAME == "Capital Regional District") %>% 
  collect()

## Plot the Capital Regional District polygon with ggplot()
my_regional_district  %>% 
  ggplot() +
  geom_sf()

