
#usethis::use_mit_license("Victor Kilanko")

#' Create a Causal Assignment Tree (CAT) specification
#'
#' Standardizes columns and assigns canonical CAT nodes that match the diagram:
#' (1) t<g,p=0 ; (2) t<g,p=1 ; (3) t>=g,p=0 ; (4) t>=g,p=1 ; (5) NT,p=0 ; (6) NT,p=1
#'
#' @param data data.frame (panel)
#' @param id   string: unit id column (e.g., hospital id)
#' @param time string: time column (e.g., year)
#' @param g    string: first-treated time for the group (cohort time). use Inf/0 for never-treated.
#' @param subgroup string: subgroup/eligibility indicator p (e.g., NP=1, FP=0)
#' @param group_id optional label for the policy-adopting unit (e.g., state code)
#' @param never_treated_values numeric vector for g that mean "never treated" (default c(0, Inf))
#' @returns object of class `cat_spec`
#' @export
cat_spec <- function(data, id, time, g, subgroup,
                     group_id = NULL,
                     never_treated_values = c(0, Inf)) {
  stopifnot(all(c(id, time, g, subgroup) %in% names(data)))
  d <- data
  d$.id       <- d[[id]]
  d$.time     <- d[[time]]
  d$.g        <- d[[g]]
  d$.subgroup <- d[[subgroup]]
  d$.group_id <- if (!is.null(group_id)) d[[group_id]] else NA

  d$.NT  <- as.integer(d$.g %in% never_treated_values)  # never-treated groups
  d$.NYT <- as.integer(d$.time < d$.g)                  # not-yet-treated at time t

  d$.node <- dplyr::case_when(
    d$.NT == 1 & d$.subgroup == 0 ~ "(5) NT, p=0",
    d$.NT == 1 & d$.subgroup == 1 ~ "(6) NT, p=1",
    d$.NT == 0 & d$.time <  d$.g & d$.subgroup == 0 ~ "(1) t<g, p=0",
    d$.NT == 0 & d$.time <  d$.g & d$.subgroup == 1 ~ "(2) t<g, p=1",
    d$.NT == 0 & d$.time >= d$.g & d$.subgroup == 0 ~ "(3) t≥g, p=0",
    d$.NT == 0 & d$.time >= d$.g & d$.subgroup == 1 ~ "(4) t≥g, p=1",
    TRUE ~ "Unclassified"
  )

  meta <- list(id=id, time=time, g=g, subgroup=subgroup, group_id=group_id,
               never_treated_values=never_treated_values)

  out <- list(data = d, meta = meta)
  class(out) <- "cat_spec"
  out
}

#' Pretty printer
#' @export
print.cat_spec <- function(x, ...) {
  d <- x$data
  cat("CAT spec\n")
  str(x$meta)
  cat("\nNode counts:\n")
  print(dplyr::count(d, .node, name="n"))
  invisible(x)
}
