# ============================================================
# cat_spec(): Build CAT specification
# Supports: DiD, CSDID, DR-DDD with cohort letters A-Z
# ============================================================

#' Build a Causal Assignment Tree specification
#'
#' `cat_spec()` is the entry point for `catviz`. It attaches internal
#' standardised columns (`.id`, `.time`, `.g`, `.subgroup`, `.NT`, `.NYT`,
#' `.node`) to your panel data and records the variable mapping so that all
#' downstream functions know where to look.
#'
#' @param data A data frame (panel structure: one row per unit x time period).
#' @param id Name of the **unit** identifier column (e.g. `"hospital_id"`).
#' @param time Name of the **time** column (e.g. `"year"` or `"date"`).
#' @param g Name of the **first treatment period** column. Units that never
#'   receive treatment should have `g = Inf` (or another value listed in
#'   `never_treated_values`).
#' @param subgroup *(optional)* Name of a binary subgroup column (0/1), used
#'   for **DR-DDD** designs. Omit or set `NULL` for pure **CSDID**.
#' @param group_id *(optional)* Name of a higher-level grouping column (e.g.
#'   `"state"`) when treatment is assigned at a level above the unit.
#' @param never_treated_values Numeric vector of `g` values that indicate
#'   never-treated status. Default: `c(0, Inf)`.
#'
#' @return A `cat_spec` object: a list with elements
#'   * `$data`  - the augmented data frame
#'   * `$meta`  - a list of variable names and settings
#'
#' @export
#' @examples
#' df <- data.frame(
#'   id   = rep(1:4, each = 3),
#'   year = rep(2018:2020, 4),
#'   g    = c(rep(2019, 6), rep(Inf, 6))
#' )
#' spec <- cat_spec(df, id = "id", time = "year", g = "g")
#'
#' df$p <- rep(c(0, 1), 6)
#' spec_ddd <- cat_spec(df, id = "id", time = "year", g = "g", subgroup = "p")
cat_spec <- function(data,
                     id,
                     time,
                     g,
                     subgroup = NULL,
                     group_id = NULL,
                     never_treated_values = c(0, Inf)) {

  # ----------- Basic error checking -----------
  vars <- c(id, time, g, subgroup)
  vars <- vars[!is.null(vars)]

  stopifnot(all(vars %in% names(data)))

  d <- data

  # ----------- Standardized internal variables -----------
  d$.id       <- d[[id]]
  d$.time     <- d[[time]]
  d$.g        <- d[[g]]
  d$.subgroup <- if (!is.null(subgroup)) d[[subgroup]] else NA_integer_
  d$.group_id <- if (!is.null(group_id)) d[[group_id]] else NA

  # ----------- Never-treated indicator -----------
  d$.NT  <- as.integer(d$.g %in% never_treated_values | is.infinite(d$.g))
  d$.NYT <- as.integer(d$.time < d$.g)   # not yet treated

  # ----------- Raw node classification -----------
  d$.node <- dplyr::case_when(
    d$.NT == 1 & d$.subgroup == 0 ~ "(5) NT, p=0",
    d$.NT == 1 & d$.subgroup == 1 ~ "(6) NT, p=1",
    d$.NT == 1                     ~ "(NT) Never-Treated",

    d$.NT == 0 & d$.time <  d$.g & d$.subgroup == 0 ~ "(1) t<g, p=0",
    d$.NT == 0 & d$.time <  d$.g & d$.subgroup == 1 ~ "(2) t<g, p=1",
    d$.NT == 0 & d$.time <  d$.g                    ~ "(pre) t<g",

    d$.NT == 0 & d$.time >= d$.g & d$.subgroup == 0 ~ "(3) t>=g, p=0",
    d$.NT == 0 & d$.time >= d$.g & d$.subgroup == 1 ~ "(4) t>=g, p=1",
    d$.NT == 0 & d$.time >= d$.g                    ~ "(post) t>=g",

    TRUE ~ "Unclassified"
  )

  # ----------- Metadata -----------
  meta <- list(
    id        = id,
    time      = time,
    g         = g,
    subgroup  = subgroup,
    group_id  = group_id,
    never_treated_values = never_treated_values
  )

  out <- list(data = d, meta = meta)
  class(out) <- "cat_spec"
  return(out)
}
