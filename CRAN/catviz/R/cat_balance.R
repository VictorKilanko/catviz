#' Standardized mean differences across CAT nodes or design groups
#' @param spec cat_spec (labeled for by='design')
#' @param covariates character vector
#' @param by 'node' or 'design'. 'design' compares Treated vs Control if labeled.
#' @param weight optional weight column
#' @export
cat_balance_table <- function(spec, covariates, by = c("node","design"), weight = NULL) {
  by <- match.arg(by)
  d <- spec$data
  stopifnot(all(covariates %in% names(d)))
  w <- if (is.null(weight)) rep(1, nrow(d)) else d[[weight]]
  d$.w <- w

  if (by == "design") {
    # Use NT indicator to split Treated vs Never-Treated
    d$grp <- dplyr::case_when(
      d$.NT == 0 ~ "Treated",
      d$.NT == 1 ~ "Never-Treated",
      TRUE       ~ NA_character_
    )
    d <- d[!is.na(d$grp), , drop = FALSE]
    split_col <- "grp"
  } else {
    split_col <- ".node"
  }

  wmean <- function(x, w) sum(w * x, na.rm=TRUE) / sum(w[!is.na(x)])
  wvar  <- function(x, w) {
    m <- wmean(x, w); sum(w * (x - m)^2, na.rm=TRUE) / sum(w[!is.na(x)])
  }

  purrr::map_dfr(covariates, function(v) {
    dd <- d[, c(split_col, v, ".w")]
    colnames(dd) <- c("g","x",".w")
    stats <- dd |>
      dplyr::group_by(g) |>
      dplyr::summarise(m = wmean(x,.w), s2 = wvar(x,.w), .groups="drop")
    ref <- stats$m[1]
    smd <- (stats$m - ref) / sqrt( (stats$s2 + stats$s2[1]) / 2 )
    dplyr::tibble(covariate = v, group = stats$g, mean = stats$m, smd = smd)
  })
}

#' Love plot for balance
#' @param balance_tbl A balance table as returned by \code{cat_balance_table()},
#'   containing columns \code{covariate}, \code{smd}, and \code{group}.
#' @return A ggplot object showing standardized mean differences by covariate.
#' @export
cat_balance_plot <- function(balance_tbl) {
  ggplot2::ggplot(balance_tbl, ggplot2::aes(x = smd, y = covariate, shape = group)) +
    ggplot2::geom_vline(xintercept = 0) +
    ggplot2::geom_point(size = 2.7) +
    ggplot2::theme_minimal() +
    ggplot2::labs(x = "Standardized mean difference", y = NULL, shape = NULL,
                  title = "Covariate balance across CAT groups")
}
