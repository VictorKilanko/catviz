# ============================================================
#  CAT Diagnostics - event counts, DR-DDD, and CSDID pretrends
# ============================================================

#' Count treated and control observations by event time
#'
#' Summarizes the number of treated and control observations by event time
#' `e = t - g`. Works directly with any `cat_spec` object; does not require
#' any additional labeling.
#'
#' @param spec A `cat_spec` object (from [cat_spec()])
#' @param event_window Integer vector of event times to include (default `-10:10`)
#' @return A tibble with columns `e`, `n_treated`, `n_control`
#' @examples
#' df <- data.frame(
#'   id   = rep(1:10, each = 6),
#'   year = rep(2015:2020, 10),
#'   g    = c(rep(2018, 30), rep(Inf, 30))
#' )
#' spec <- cat_spec(df, id = "id", time = "year", g = "g")
#' cat_event_table(spec, event_window = -3:2)
#' @export
cat_event_table <- function(spec, event_window = -10:10) {
  d <- spec$data

  d |>
    dplyr::filter(.NT == 0) |>
    dplyr::mutate(
      e          = .time - .g,
      .is_post   = .time >= .g,
      .is_pre    = .time <  .g
    ) |>
    dplyr::filter(e %in% event_window) |>
    dplyr::group_by(e) |>
    dplyr::summarise(
      n_treated = sum(.is_post, na.rm = TRUE),
      n_control = sum(.is_pre,  na.rm = TRUE),
      .groups   = "drop"
    )
}


#' DR-DDD pretrend diagnostic: subgroup means in pre-periods
#'
#' Plots mean outcomes for the treated subgroup (subgroup = 1) vs. the control
#' subgroup (subgroup = 0) across pre-treatment event-time periods. Requires a
#' `subgroup` variable in the `cat_spec`.
#'
#' @param spec A `cat_spec` object with a subgroup variable
#' @param y Name of the outcome variable
#' @param pre_window Integer vector of pre-periods (default `-8:-1`)
#' @return A list with elements `data` (tibble) and `plot` (ggplot)
#' @examples
#' set.seed(42)
#' df <- data.frame(
#'   id      = rep(1:10, each = 6),
#'   year    = rep(2015:2020, 10),
#'   g       = c(rep(2018, 30), rep(Inf, 30)),
#'   p       = rep(c(0L, 1L), 30),
#'   outcome = rnorm(60)
#' )
#' spec <- cat_spec(df, id = "id", time = "year", g = "g", subgroup = "p")
#' result <- cat_pt_drddd(spec, y = "outcome", pre_window = -3:-1)
#' @export
cat_pt_drddd <- function(spec, y, pre_window = -8:-1) {
  d <- spec$data
  stopifnot(y %in% names(d))

  if (!".subgroup" %in% names(d) || all(is.na(d$.subgroup))) {
    stop("DR-DDD diagnostic requires a subgroup variable. ",
         "Did you pass `subgroup` to cat_spec()?", call. = FALSE)
  }

  dd <- d |>
    dplyr::filter(.NT == 0) |>
    dplyr::mutate(
      e   = .time - .g,
      grp = dplyr::case_when(
        .subgroup == 1 ~ "Treated (Q=1)",
        .subgroup == 0 ~ "Control (Q=0)",
        TRUE           ~ NA_character_
      )
    ) |>
    dplyr::filter(e %in% pre_window, !is.na(grp)) |>
    dplyr::group_by(grp, e) |>
    dplyr::summarise(mean_y = mean(.data[[y]], na.rm = TRUE), .groups = "drop")

  p <- ggplot2::ggplot(dd, ggplot2::aes(e, mean_y, color = grp)) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::geom_point(size = 2) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "grey60") +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::labs(
      x     = "Event time (pre-treatment)",
      y     = "Mean outcome",
      color = NULL,
      title = "DR-DDD Pretrend Diagnostic"
    )

  list(data = dd, plot = p)
}


#' CSDiD parallel-gaps diagnostic
#'
#' Checks whether treated cohorts and the never-treated group have parallel
#' pre-treatment trends. Plots the gap `mean(treated) - mean(never-treated)`
#' across pre-treatment event-time periods.
#'
#' @param spec A `cat_spec` object
#' @param y Outcome variable name
#' @param pre_window Integer vector of pre-periods (default `-8:-1`)
#' @return A list with `data` (tibble) and `plot` (ggplot)
#' @examples
#' set.seed(42)
#' df <- data.frame(
#'   id      = rep(1:10, each = 6),
#'   year    = rep(2015:2020, 10),
#'   g       = c(rep(2018, 30), rep(Inf, 30)),
#'   outcome = rnorm(60)
#' )
#' spec <- cat_spec(df, id = "id", time = "year", g = "g")
#' result <- cat_pt_csdid(spec, y = "outcome", pre_window = -3:-1)
#' @export
cat_pt_csdid <- function(spec, y, pre_window = -8:-1) {
  d <- spec$data
  stopifnot(y %in% names(d))

  # Step 1: treated units in pre-window — event time is relative to their own g
  trt <- d[d$.NT == 0, ]
  trt$e <- trt$.time - trt$.g
  trt <- trt[trt$e %in% pre_window, ]

  if (nrow(trt) == 0) {
    warning("No treated observations found in pre_window. Check your pre_window values.")
    return(list(data = data.frame(e=integer(), mean_trt=numeric(),
                                  mean_ctl=numeric(), gap=numeric()), plot = NULL))
  }

  # Step 2: mean treated outcome by event time
  mean_trt <- aggregate(trt[[y]], by = list(e = trt$e), FUN = mean, na.rm = TRUE)
  names(mean_trt)[2] <- "mean_trt"

  # Step 3: match never-treated by calendar year (not event time)
  # Different cohorts at the same event time e are at different calendar years,
  # so we join never-treated means onto the treated rows by calendar year first,
  # then average up to event time.
  nt <- d[d$.NT == 1, ]

  nt_by_year <- aggregate(nt[[y]], by = list(.time = nt$.time),
                          FUN = mean, na.rm = TRUE)
  names(nt_by_year)[2] <- "nt_y"

  e_years <- unique(trt[, c("e", ".time")])
  e_nt    <- merge(e_years, nt_by_year, by = ".time", all.x = TRUE)

  mean_ctl <- aggregate(e_nt$nt_y, by = list(e = e_nt$e), FUN = mean, na.rm = TRUE)
  names(mean_ctl)[2] <- "mean_ctl"

  # Step 4: join and compute gap
  dd <- merge(mean_trt, mean_ctl, by = "e")
  dd$gap <- dd$mean_trt - dd$mean_ctl
  dd <- dd[order(dd$e), ]

  p <- ggplot2::ggplot(dd, ggplot2::aes(e, gap)) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "grey60") +
    ggplot2::geom_line(linewidth = 0.8, color = "#4B6EAF") +
    ggplot2::geom_point(size = 2.5, color = "#4B6EAF") +
    ggplot2::scale_x_continuous(breaks = pre_window) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = NA)
    ) +
    ggplot2::labs(
      x     = "Event time (years relative to treatment)",
      y     = "Gap: mean(treated) - mean(never-treated)",
      title = "CSDiD Parallel-Trends Diagnostic"
    )

  list(data = dd, plot = p)
}


#' General diagnostic helper for CAT specifications
#'
#' Automatically selects an appropriate diagnostic based on the method argument.
#' Dispatches to:
#' - "event" -> [cat_event_table()] (event-time counts; no outcome needed)
#' - "drddd" -> [cat_pt_drddd()] (subgroup pretrend plot)
#' - "csdid" -> [cat_pt_csdid()] (parallel-gaps plot)
#'
#' @param spec A `cat_spec` object
#' @param outcome Outcome variable name (required for `"drddd"` and `"csdid"`)
#' @param method Diagnostic type: `"event"`, `"drddd"`, or `"csdid"`
#' @param ... Additional arguments passed to the specific diagnostic function
#'   (e.g., `pre_window`)
#' @return A list with diagnostic results (always includes `data`; includes
#'   `plot` for `"drddd"` and `"csdid"`)
#' @export
#' @examples
#' df <- data.frame(id=rep(1:10,each=6), year=rep(2015:2020,10),
#'                  g=c(rep(2018,30),rep(Inf,30)), outcome=rnorm(60))
#' spec <- cat_spec(df, id="id", time="year", g="g")
#' result <- cat_diag(spec, method = "event")
cat_diag <- function(spec,
                     outcome = NULL,
                     method  = c("event", "drddd", "csdid"),
                     ...) {
  method <- match.arg(method)

  if (method == "event") {
    message("Using event-time count diagnostic (cat_event_table)")
    result <- cat_event_table(spec, ...)
  } else if (method == "drddd") {
    if (is.null(outcome)) stop("Please specify `outcome` for DR-DDD diagnostics.", call. = FALSE)
    message("Using DR-DDD pretrend diagnostic (cat_pt_drddd)")
    result <- cat_pt_drddd(spec, y = outcome, ...)
  } else {
    if (is.null(outcome)) stop("Please specify `outcome` for CSDID diagnostics.", call. = FALSE)
    message("Using CSDID parallel-trends diagnostic (cat_pt_csdid)")
    result <- cat_pt_csdid(spec, y = outcome, ...)
  }

  if (is.list(result) && "plot" %in% names(result)) {
    print(result$plot)
  }

  invisible(result)
}
