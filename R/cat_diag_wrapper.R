#' General diagnostic helper for CAT specifications
#'
#' Provides a quick check on event counts or pretrend balance,
#' depending on available labeling.
#'
#' @param spec A labeled cat_spec object
#' @param outcome Optional outcome variable name for pretrend plots
#' @param method Diagnostic type: "event", "drddd", or "csdid"
#' @param ... Additional arguments passed to specific diagnostic functions
#' @return A list containing data and (optionally) a ggplot
#' @export
cat_diag <- function(spec, outcome = NULL, method = c("event", "drddd", "csdid"), ...) {
  method <- match.arg(method)
  
  if (method == "event") {
    return(cat_event_table(spec, ...))
  }
  
  if (is.null(outcome)) {
    stop("Please provide an outcome variable name for DR-DDD or CSDID diagnostics.", call. = FALSE)
  }
  
  if (method == "drddd") {
    return(cat_pt_drddd(spec, y = outcome, ...))
  }
  
  if (method == "csdid") {
    return(cat_pt_csdid(spec, y = outcome, ...))
  }
}
