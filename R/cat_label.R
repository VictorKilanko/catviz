#' Automatically label CAT nodes
#'
#' @description
#' Standardizes node labels in a Causal Assignment Tree (CAT)
#' following the conventional numbering:
#' (1)–(6) for pre/post-treatment and never-treated groups.
#'
#' @param spec A cat_spec object (as created by `cat_spec()`).
#'
#' @return The same cat_spec object, with `.node` values labeled.
#' @export
cat_label <- function(spec) {
  if (!"data" %in% names(spec))
    stop("`spec` must be a cat_spec object created with cat_spec().")
  
  d <- spec$data
  
  if (!".node" %in% names(d)) {
    warning("No .node column found. Nothing to label.")
    return(spec)
  }
  
  d <- dplyr::mutate(
    d,
    .node = dplyr::case_when(
      grepl("NT", .node, fixed = TRUE) & grepl("p=0", .node) ~ "(5) NT, p=0",
      grepl("NT", .node, fixed = TRUE) & grepl("p=1", .node) ~ "(6) NT, p=1",
      grepl("t<g", .node, fixed = TRUE) & grepl("p=0", .node) ~ "(1) t<g, p=0",
      grepl("t<g", .node, fixed = TRUE) & grepl("p=1", .node) ~ "(2) t<g, p=1",
      grepl("t≥g", .node, fixed = TRUE) & grepl("p=0", .node) ~ "(3) t≥g, p=0",
      grepl("t≥g", .node, fixed = TRUE) & grepl("p=1", .node) ~ "(4) t≥g, p=1",
      TRUE ~ .node
    )
  )
  
  spec$data <- d
  return(spec)
}
