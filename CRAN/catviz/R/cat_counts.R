#' Count observations or units per node
#'
#' @param spec A cat_spec or labeled cat_spec object
#' @return A tibble with counts per node
#' @export
cat_counts <- function(spec) {
  d <- spec$data
  id_col <- spec$meta$id

  d |>
    dplyr::group_by(.node) |>
    dplyr::summarise(n = dplyr::n_distinct(.data[[id_col]]), .groups = "drop") |>
    dplyr::arrange(.node)
}
