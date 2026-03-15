# ============================================================
# utils.R -- Internal utilities
# ============================================================

# Import %||% from rlang so it is available package-wide
#' @importFrom rlang `%||%`
NULL

# Suppress R CMD check "no visible binding for global variable" notes
# arising from ggplot2/dplyr non-standard evaluation.
utils::globalVariables(c(
  # dplyr/tidyr column names used in NSE
  ".NT", ".data", ".g", ".is_post", ".is_pre", ".node", ".time", ".w",
  # cat_balance variables
  "covariate", "g", "group", "smd", "x",
  # cat_diag / pretrend variables
  "e", "gap", "grp", "mean_ctl", "mean_trt", "mean_y",
  # cat_plot layout variables
  "g_val", "label", "leaf_name", "letter", "n", "n.x", "n.y",
  "name", "node_name", "Q", "role",
  "x", "x_from", "x_new", "x_pos", "x_to",
  "y", "y_from", "y_to"
))
