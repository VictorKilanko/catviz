#' Label treated/control under DR-DDD (NYT controls, with NT optional)
#' @param spec cat_spec
#' @param include_never_treated logical; if TRUE, controls include nodes (5)-(6)
#' @export
cat_label_drddd <- function(spec, include_never_treated = TRUE) {
  d <- spec$data
  treated <- (d$.subgroup == 1 & d$.NT == 0 & d$.time >= d$.g)  # Node (4)

  if (include_never_treated) {
    control <- (d$.NYT == 1)            # Nodes (1)-(2) and (5)-(6)
  } else {
    control <- (d$.NYT == 1 & d$.NT==0)  # Nodes (1)-(2) only
  }

  spec$data$.treated <- as.logical(treated)
  spec$data$.control <- as.logical(control)
  spec$data$.design  <- "drddd"
  spec
}

#' Label treated/control under CSDID within a subgroup p
#' @param spec cat_spec
#' @param subgroup_value 0/1 indicating which subgroup to analyze
#' @export
cat_label_csdid <- function(spec, subgroup_value = 1) {
  d <- spec$data
  treated <- (d$.subgroup == subgroup_value & d$.NT == 0 & d$.time >= d$.g)
  control <- (d$.subgroup == subgroup_value & d$.NT == 1)   # never-treated within subgroup
  spec$data$.treated <- as.logical(treated)
  spec$data$.control <- as.logical(control)
  spec$data$.design  <- paste0("csdid_p=", subgroup_value)
  spec
}

#' Helper to select a design quickly
#' @export
cat_define_controls <- function(spec,
                                design = c("drddd","csdid"),
                                include_never_treated = TRUE,
                                subgroup_value = 1) {
  design <- match.arg(design)
  if (design == "drddd") {
    cat_label_drddd(spec, include_never_treated)
  } else {
    cat_label_csdid(spec, subgroup_value)
  }
}
