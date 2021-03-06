# Copyright 2019 Province of British Columbia
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.

# Ensure these are loaded first so dblplyr::sql_translator
# can find them
#' @include cql-geom-predicates.R
NULL

#' @importFrom rlang :=

# Function to translate R code to CQL
cql_translate <- function(...) {
  ## convert dots to list of quosures
  dots <- rlang::quos(...)
  ## run partial_eval on them to evaluate named objects in the environment
  ## in which they were defined.
  ## e.g., if x is defined in the global env and passed as on object to
  ## filter, need to evaluate x in the global env.
  ## This also evaluates any functions defined in cql_scalar so that the spatial
  ## predicates and CQL() expressions are evaluated into valid CQL code
  ## so they can be combined with the rest of the query
  dots <- lapply(dots, function(x) {

    # make sure all arguments are named in the call so can be modified
    x <- rlang::call_standardise(x, env = rlang::get_env(x))

    # if an argument to a predicate is a function call, need to tell it to evaluate
    # locally, as by default all functions are treated as remote and thus
    # not evaluated. Do this by using `rlang::call2` to wrap the function call in
    # local()
    # See ?rlang::partial_eval and https://github.com/bcgov/bcdata/issues/146
    for (call_arg in rlang::call_args_names(x)) {
      if (is.call(rlang::call_args(x)[[call_arg]])) {
        x <- rlang::call_modify(
          x, !!call_arg := rlang::call2("local", rlang::call_args(x)[[call_arg]])
        )
      }
    }

    rlang::new_quosure(dbplyr::partial_eval(x), rlang::get_env(x))
  })

  sql_where <- dbplyr::translate_sql_(dots, con = wfs_con, window = FALSE)

  build_where(sql_where)
}

# Builds a complete WHERE clause from a vector of WHERE statements
# Modified from dbplyr:::sql_clause_where
build_where <- function(where, con = wfs_con) {
  if (length(where) > 0L) {
    where_paren <- dbplyr::escape(where, parens = TRUE, con = con)
    dbplyr::build_sql(
      dbplyr::sql_vector(where_paren, collapse = " AND ", con = con),
      con = con
    )
  }
}

bcdc_identity <- function(f) {
  function(x, ...) {
    do.call(f, c(x, list(...)))
  }
}

# Define custom translations from R functions to filter functions supported
# by cql: https://docs.geoserver.org/stable/en/user/filter/function_reference.html
cql_scalar <- dbplyr::sql_translator(
  .parent = dbplyr::base_scalar,
  tolower = dbplyr::sql_prefix("strToLowerCase", 1),
  toupper = dbplyr::sql_prefix("strToUpperCase", 1),
  between = function(x, left, right) {
    CQL(paste0(x, " BETWEEN ", left, " AND ", right))
  },
  CQL = CQL,
  # Override dbplyr::base_scalar functions which convert to SQL
  # operations intended for the backend database, but we want them to operate
  # locally
  `[` = `[`,
  `[[` = `[[`,
  `$` = `$`,
  as.Date = function(x, ...) as.character(as.Date(x, ...)),
  as.POSIXct = function(x, ...) as.character(as.POSIXct(x, ...)),
  as.numeric = bcdc_identity("as.numeric"),
  as.double = bcdc_identity("as.double"),
  as.integer = bcdc_identity("as.integer"),
  as.character = bcdc_identity("as.character"),
  as.logical = function(x, ...) as.character(as.logical(x, ...)),
  # Geometry predicates
  EQUALS = EQUALS,
  DISJOINT = DISJOINT,
  INTERSECTS = INTERSECTS,
  TOUCHES = TOUCHES,
  CROSSES = CROSSES,
  WITHIN = WITHIN,
  CONTAINS = CONTAINS,
  OVERLAPS = OVERLAPS,
  RELATE = RELATE,
  DWITHIN = DWITHIN,
  BEYOND = BEYOND,
  BBOX = BBOX
)

# No aggregation functions available in CQL
no_agg <- function(f) {
  force(f)

  function(...) {
    stop("Aggregation function `", f, "()` is not supported by this database",
         call. = FALSE)
  }
}

# Construct the errors for common aggregation functions
cql_agg <- dbplyr::sql_translator(
  n          = no_agg("n"),
  mean       = no_agg("mean"),
  var        = no_agg("var"),
  sum        = no_agg("sum"),
  min        = no_agg("min"),
  max        = no_agg("max")
)

#' wfsConnection class
#'
#' @import methods
#' @import DBI
#' @export
#' @keywords internal
setClass("wfsConnection",
         contains = "DBIConnection"
)

# A dummy connection object to ensure the correct sql_translate is used
wfs_con <- structure(
  list(),
  class = c("wfsConnection", "DBIConnection")
)

# Custom sql_translator using cql variants defined above
#' @keywords internal
#' @importFrom dplyr sql_translate_env
#' @export
# TODO: After dbplyr 2.0 I think this will be sql_translation, with
# generic from dbplyr rather than dplyr
# (https://dbplyr.tidyverse.org/dev/articles/backend-2.html)
sql_translate_env.wfsConnection <- function(conn) {
  dbplyr::sql_variant(
    cql_scalar,
    cql_agg,
    dbplyr::base_no_win
  )
}

# Make sure that identities (LHS of relations) are escaped with double quotes
# TODO: After dbplyr 2.0 I think we can remove these and move the body into dbQuoteIdentifier
#' @keywords internal
#' @importFrom dplyr sql_escape_ident
#' @export
sql_escape_ident.wfsConnection <- function(conn, x) {
  dbplyr::sql_quote(x, "\"")
}

# Make sure that strings (RHS of relations) are escaped with single quotes
# TODO: After dbplyr 2.0 I think we can remove these and move the body into dbQuoteString
#' @keywords internal
#' @importFrom dplyr sql_escape_string
#' @export
sql_escape_string.wfsConnection <- function(conn, x) {
  dbplyr::sql_quote(x, "'")
}

# Make sure that identities (LHS of relations) are escaped with double quotes

#' @keywords internal
#' @rdname wfsConnection-class
#' @exportMethod dbQuoteIdentifier
#' @export
setMethod("dbQuoteIdentifier", c("wfsConnection", "ANY"),
          sql_escape_ident.wfsConnection)

# Make sure that strings (RHS of relations) are escaped with single quotes

#' @keywords internal
#' @rdname wfsConnection-class
#' @exportMethod dbQuoteString
#' @export
setMethod("dbQuoteString", c("wfsConnection", "ANY"),
          sql_escape_string.wfsConnection)
