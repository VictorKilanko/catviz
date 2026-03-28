#' Show ATT contrast implied by CAT nodes and design
#'
#' Returns LaTeX and plain-text versions of the ATT equation that match the
#' Causal Assignment Tree diagram.
#'
#' @param design Character; either \code{"drddd"} or \code{"csdid"}.
#' @param subgroup_value Integer; 0 or 1 selecting the subgroup for CSDiD contrast.
#' @param include_never_treated Logical; if \code{TRUE} (default), a note about
#'   never-treated controls is included in the output.
#' @return A named list with four elements:
#' \itemize{
#'   \item \code{text} - plain-text representation of the ATT contrast equation.
#'   \item \code{tex} - LaTeX math string of the ATT contrast equation.
#'   \item \code{nodes} - character vector naming the CAT nodes involved in the contrast.
#'   \item \code{note} - plain-text note about the control group composition.
#' }
#' @examples
#' eq <- cat_att_equation(design = "csdid")
#' cat(eq$text)
#'
#' eq2 <- cat_att_equation(design = "drddd")
#' cat(eq2$text)
#' @export
cat_att_equation <- function(design = c("drddd","csdid"),
                             subgroup_value = 1,
                             include_never_treated = TRUE) {
  design <- match.arg(design)
  if (design == "drddd") {
    list(
      text = "ATT_DDD = (Y4 - Y2) - (Y3 - Y1)",
      tex  = "\\mathrm{ATT}_{DDD} = (Y_{(4)}-Y_{(2)})-(Y_{(3)}-Y_{(1)})",
      nodes = c("(4) t>=g,p=1","(2) t<g,p=1","(3) t>=g,p=0","(1) t<g,p=0"),
      note  = if (include_never_treated)
        "Controls may include never-treated (nodes 5-6) when using NYT comparison logic."
      else "Controls restricted to not-yet-treated (nodes 1-2)."
    )
  } else {
    if (subgroup_value==1) {
      list(
        text = "ATT_CSDID(g,t|p=1): compare Node (4) vs Node (6) under PT within p=1.",
        tex  = "\\mathrm{ATT}_{CSDID}(g,t\\mid p{=}1): (4) \\text{ vs } (6)",
        nodes = c("treated (4) t>=g,p=1","control (6) NT,p=1"),
        note  = "Callaway-Sant'Anna ATT within subgroup p."
      )
    } else {
      list(
        text = "ATT_CSDID(g,t|p=0): compare Node (3) vs Node (5) under PT within p=0.",
        tex  = "\\mathrm{ATT}_{CSDID}(g,t\\mid p{=}0): (3) \\text{ vs } (5)",
        nodes = c("treated (3) t>=g,p=0","control (5) NT,p=0"),
        note  = "Callaway-Sant'Anna ATT within subgroup p."
      )
    }
  }
}
