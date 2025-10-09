# ============================================================
#  CAT Diagnostics — event counts, DR-DDD, and CSDID pretrends
# ============================================================

#' Counts of treated/control by event time e = t - g
#'
#' Summarizes the number of treated and control observations by event time.
#' Works with CAT-labeled data (via `cat_label()`).
#'
#' @param spec Labeled cat_spec object (via `cat_label()`)
#' @param event_window Integer vector of event times to include (default = -10:10)
#' @return A tibble with columns e, n_treated, n_control
#' @export
cat_event_table <- function(spec, event_window = -10:10) {
  d <- spec$data
  stopifnot(".treated" %in% names(d), ".control" %in% names(d))

  d |>
    dplyr::filter(.NT == 0) |>
    dplyr::mutate(e = .time - .g) |>
    dplyr::filter(e %in% event_window) |>
    dplyr::group_by(e) |>
    dplyr::summarise(
      n_treated = sum(.treated),
      n_control = sum(.control),
      .groups = "drop"
    )
}


#' DR-DDD pretrend diagnostic: treated vs control means in pre-periods
#'
#' Plots mean outcomes for treated and control groups across pre-treatment periods.
#' Requires DR-DDD labeling (`cat_label_drddd()`).
#'
#' @param spec Labeled cat_spec object (via `cat_label_drddd()`)
#' @param y Name of the outcome variable
#' @param pre_window Integer vector of pre-periods (default = -8:-1)
#' @return A list with elements: data (tibble) and plot (ggplot)
#' @export
cat_pt_drddd <- function(spec, y, pre_window = -8:-1) {
  d <- spec$data
  stopifnot(".treated" %in% names(d), ".control" %in% names(d), y %in% names(d))

  dd <- d |>
    dplyr::filter(.NT == 0) |>
    dplyr::mutate(
      e = .time - .g,
      grp = dplyr::case_when(
        .treated ~ "Treated",
        .control ~ "Control",
        TRUE ~ NA_character_
      )
    ) |>
    dplyr::filter(e %in% pre_window, !is.na(grp)) |>
    dplyr::group_by(grp, e) |>
    dplyr::summarise(mean_y = mean(.data[[y]], na.rm = TRUE), .groups = "drop")

  p <- ggplot2::ggplot(dd, ggplot2::aes(e, mean_y, color = grp)) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::geom_point(size = 2) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "grey60") +
    ggplot2::theme_minimal(base_size = 13, base_family = "serif") +
    ggplot2::labs(
      x = "Event time (pre)",
      y = "Mean outcome",
      color = NULL,
      title = "DR-DDD Pretrend Diagnostic"
    )

  list(data = dd, plot = p)
}


#' CSDID parallel-gaps diagnostic within subgroup p
#'
#' Checks if treated and never-treated subgroups follow parallel pretrends.
#' Requires CSDID labeling (`cat_label_csdid()`).
#'
#' @param spec Labeled cat_spec object (via `cat_label_csdid()`)
#' @param y Outcome variable name
#' @param pre_window Integer vector of pre-periods (default = -8:-1)
#' @return A list with data (tibble) and plot (ggplot)
#' @export
cat_pt_csdid <- function(spec, y, pre_window = -8:-1) {
  d <- spec$data
  stopifnot(".treated" %in% names(d), ".control" %in% names(d), y %in% names(d))

  dd <- d |>
    dplyr::mutate(
      e = .time - .g,
      grp = dplyr::case_when(
        .treated ~ "Treated subgroup",
        .control ~ "Never-treated subgroup",
        TRUE ~ NA_character_
      )
    ) |>
    dplyr::filter(e %in% pre_window, !is.na(grp)) |>
    dplyr::group_by(grp, e) |>
    dplyr::summarise(mean_y = mean(.data[[y]], na.rm = TRUE), .groups = "drop") |>
    tidyr::pivot_wider(names_from = grp, values_from = mean_y) |>
    dplyr::mutate(gap = `Treated subgroup` - `Never-treated subgroup`)

  p <- ggplot2::ggplot(dd, ggplot2::aes(e, gap)) +
    ggplot2::geom_line(linewidth = 0.8, color = "#4B6EAF") +
    ggplot2::geom_point(size = 2, color = "#4B6EAF") +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "grey60") +
    ggplot2::theme_minimal(base_size = 13, base_family = "serif") +
    ggplot2::labs(
      x = "Event time (pre)",
      y = "Gap (treated - control)",
      title = "CSDID Parallel-Gaps Diagnostic (within subgroup)"
    )

  list(data = dd, plot = p)
}


#' General diagnostic helper for CAT specifications
#'
#' Automatically selects an appropriate diagnostic based on labeling type.
#'
#' - `cat_label()`  → Event count diagnostic (`cat_event_table()`)
#' - `cat_label_drddd()` → DR-DDD pretrend diagnostic (`cat_pt_drddd()`)
#' - `cat_label_csdid()` → CSDID subgroup diagnostic (`cat_pt_csdid()`)
#'
#' @param spec A labeled cat_spec object
#' @param outcome Optional outcome variable name (required for DR-DDD/CSDID)
#' @param method Diagnostic type: "auto", "event", "drddd", or "csdid"
#' @param ... Additional arguments passed to specific diagnostics
#' @return A list with diagnostic results (data, and optionally a ggplot)
#' @export
cat_diag <- function(spec, outcome = NULL, method = c("auto", "event", "drddd", "csdid"), ...) {
  method <- match.arg(method)

  # --- Auto-detect method from class or label attribute ---
  classes <- class(spec)
  attr_lab <- attr(spec, "label_type")

  if (method == "auto") {
    if ("cat_spec_drddd" %in% classes || identical(attr_lab, "drddd")) {
      method <- "drddd"
    } else if ("cat_spec_csdid" %in% classes || identical(attr_lab, "csdid")) {
      method <- "csdid"
    } else {
      method <- "event"
    }
  }

  # --- Dispatch to appropriate diagnostic ---
  if (method == "event") {
    message("📊 Using event-time diagnostic (cat_event_table)")
    result <- cat_event_table(spec, ...)
  } else if (method == "drddd") {
    if (is.null(outcome)) stop("Please specify `outcome` for DR-DDD diagnostics.", call. = FALSE)
    message("📈 Using DR-DDD pretrend diagnostic (cat_pt_drddd)")
    result <- cat_pt_drddd(spec, y = outcome, ...)
  } else if (method == "csdid") {
    if (is.null(outcome)) stop("Please specify `outcome` for CSDID diagnostics.", call. = FALSE)
    message("📈 Using CSDID parallel-gaps diagnostic (cat_pt_csdid)")
    result <- cat_pt_csdid(spec, y = outcome, ...)
  }

  # --- Auto-plot if ggplot is present ---
  if (is.list(result) && "plot" %in% names(result)) {
    print(result$plot)
  }

  invisible(result)
}
