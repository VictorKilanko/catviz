# ============================================================
# cat_plot_tree() - unified plot dispatcher
# Automatically selects DiD, CSDiD, or DDD tree based on spec
# ============================================================

#' Plot a Causal Assignment Tree (unified interface)
#'
#' `cat_plot_tree()` is the recommended high-level function for visualizing
#' any CAT design. It inspects the `cat_spec` object and automatically
#' dispatches to the correct underlying plot function:
#'
#' | Design | Condition | Underlying function |
#' |--------|-----------|---------------------|
#' | **DDD / DR-DDD** | `subgroup` column provided, multiple `g` values | `cat_plot_ddd()` |
#' | **CSDiD** | No subgroup, multiple `g` values | `cat_plot_csdid()` |
#' | **2x2 DiD** | No subgroup, exactly one finite `g` value | `cat_plot_did()` |
#'
#' @param spec A `cat_spec` object (from [cat_spec()]).
#' @param counts Logical; include sample-size counts in node labels (default `TRUE`).
#' @param grayscale Logical; use a grayscale color palette suitable for
#'   black-and-white publications (default `FALSE`). When `TRUE`, treated
#'   nodes are shown in dark gray and control nodes in light gray.
#' @param save_plot Optional file path to save the plot (e.g. `"tree.png"`).
#'   Passed to `ggplot2::ggsave()`.
#' @param ... Additional arguments passed to the underlying plot function.
#'
#' @return A `ggplot` object.
#' @export
#' @examples
#' df <- data.frame(
#'   id   = rep(1:6, each = 4),
#'   year = rep(2017:2020, 6),
#'   g    = c(rep(2018, 8), rep(2019, 8), rep(Inf, 8))
#' )
#' spec <- cat_spec(df, id = "id", time = "year", g = "g")
#' cat_plot_tree(spec)
#'
#' df$p <- rep(c(0L, 1L), 12)
#' spec_ddd <- cat_spec(df, id = "id", time = "year", g = "g", subgroup = "p")
#' cat_plot_tree(spec_ddd)
#'
#' cat_plot_tree(spec, grayscale = TRUE)
cat_plot_tree <- function(spec,
                          counts    = TRUE,
                          grayscale = FALSE,
                          save_plot = NULL,
                          ...) {

  if (!inherits(spec, "cat_spec")) {
    stop("`spec` must be a cat_spec object. Did you run cat_spec()?", call. = FALSE)
  }

  has_subgroup <- !is.null(spec$meta$subgroup)
  g_col        <- spec$meta$g
  d            <- spec$data
  never_vals   <- spec$meta$never_treated_values %||% c(0, Inf)

  finite_gs <- sort(unique(d[[g_col]][
    !is.infinite(d[[g_col]]) & !(d[[g_col]] %in% never_vals)
  ]))

  n_finite_g <- length(finite_gs)

  if (has_subgroup && n_finite_g > 0) {
    p <- cat_plot_ddd(spec, counts = counts, save_plot = save_plot, ...)
    design_name <- "DDD"
  } else if (!has_subgroup && n_finite_g == 1) {
    p <- cat_plot_did(spec, counts = counts, save_plot = save_plot, ...)
    design_name <- "2x2 DiD"
  } else {
    p <- cat_plot_csdid(spec, counts = counts, save_plot = save_plot, ...)
    design_name <- "CSDiD"
  }

  # Apply grayscale palette if requested
  if (grayscale) {
    p <- p + ggplot2::scale_fill_manual(
      values = c(
        none    = "#FFFFFF",
        control = "#C8C8C8",   # light gray
        treated = "#606060"    # dark gray
      )
    )
  }

  message("CAT design detected: ", design_name)
  return(p)
}
