#' Show ATT contrast implied by CAT nodes and design
#' Returns LaTeX and plain-text versions that match the diagram.
#' @param design 'drddd' or 'csdid'
#' @param subgroup_value 0/1 for csdid
#' @param include_never_treated logical for drddd note
#' @export
cat_att_equation <- function(design = c("drddd","csdid"),
                             subgroup_value = 1,
                             include_never_treated = TRUE) {
  design <- match.arg(design)
  if (design == "drddd") {
    list(
      text = "ATT_DDD = (Y4 - Y2) - (Y3 - Y1)",
      tex  = "\\mathrm{ATT}_{DDD} = (Y_{(4)}-Y_{(2)})-(Y_{(3)}-Y_{(1)})",
      nodes = c("(4) t≥g,p=1","(2) t<g,p=1","(3) t≥g,p=0","(1) t<g,p=0"),
      note  = if (include_never_treated)
        "Controls may include never-treated (nodes 5-6) when using NYT comparison logic."
      else "Controls restricted to not-yet-treated (nodes 1-2)."
    )
  } else {
    if (subgroup_value==1) {
      list(
        text = "ATT_CSDID(g,t|p=1): compare Node (4) vs Node (6) under PT within p=1.",
        tex  = "\\mathrm{ATT}_{CSDID}(g,t\\mid p{=}1): (4) \\text{ vs } (6)",
        nodes = c("treated (4) t≥g,p=1","control (6) NT,p=1"),
        note  = "Callaway–Sant’Anna ATT within subgroup p."
      )
    } else {
      list(
        text = "ATT_CSDID(g,t|p=0): compare Node (3) vs Node (5) under PT within p=0.",
        tex  = "\\mathrm{ATT}_{CSDID}(g,t\\mid p{=}0): (3) \\text{ vs } (5)",
        nodes = c("treated (3) t≥g,p=0","control (5) NT,p=0"),
        note  = "Callaway–Sant’Anna ATT within subgroup p."
      )
    }
  }
}
