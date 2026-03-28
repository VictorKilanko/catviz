#' Save a CAT ggplot as a high-quality PNG
#'
#' @param plot A ggplot object (e.g., from cat_plot_tree())
#' @param filename Path to save the PNG (e.g., "CAT_plot.png")
#' @param width Width in inches (default = 10)
#' @param height Height in inches (default = 6)
#' @param dpi Resolution in dots per inch (default = 400)
#' @return Invisibly returns the file path
#' @examples
#' \dontrun{
#'   df <- data.frame(
#'     id   = rep(1:4, each = 3),
#'     year = rep(2018:2020, 4),
#'     g    = c(rep(2019, 6), rep(Inf, 6))
#'   )
#'   spec <- cat_spec(df, id = "id", time = "year", g = "g")
#'   p <- cat_plot_tree(spec)
#'   cat_save_png(p, filename = tempfile(fileext = ".png"))
#' }
#' @export
cat_save_png <- function(plot, filename = "CAT_plot.png",
                         width = 10, height = 6, dpi = 400) {
  if (!inherits(plot, "ggplot")) {
    stop("`plot` must be a ggplot object, such as returned by cat_plot_tree().", call. = FALSE)
  }

  ggplot2::ggsave(
    filename = filename,
    plot = plot,
    width = width,
    height = height,
    dpi = dpi
  )

  message(glue::glue("Plot saved to {filename}"))
  invisible(filename)
}
