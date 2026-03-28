#' Count observations or units per node
#'
#' @param spec A cat_spec or labeled cat_spec object
#' @return A tibble with counts per node
#' @examples
#' df <- data.frame(
#'   id   = rep(1:4, each = 3),
#'   year = rep(2018:2020, 4),
#'   g    = c(rep(2019, 6), rep(Inf, 6))
#' )
#' spec <- cat_spec(df, id = "id", time = "year", g = "g")
#' cat_counts(spec)
#' @export
cat_counts <- function(spec) {
  d <- spec$data
  id_col <- spec$meta$id

  d |>
    dplyr::group_by(.node) |>
    dplyr::summarise(n = dplyr::n_distinct(.data[[id_col]]), .groups = "drop") |>
    dplyr::arrange(.node)
}
