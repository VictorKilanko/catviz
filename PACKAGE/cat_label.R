#' Label CAT nodes with cohort letters and canonical g labels
#'
#' Adds three columns to `spec$data`:
#' - `.cohort_letter`: uppercase letter assigned chronologically to each finite g cohort
#' - `.g_label`: canonical label (`"g = 2015"` or `"g = Inf"`)
#' - `.g_pretty`: combined label (`"g = 2015 (A)"`)
#'
#' Never-treated units (`g = Inf` or `g %in% never_treated_values`) are
#' labeled with the last letter in the sequence.
#'
#' @param spec A `cat_spec` object (from [cat_spec()])
#' @return The same `cat_spec` object with three new columns added to `spec$data`
#' @export
#' @examples
#' # After building a spec, label it:
#' # spec <- cat_spec(mydata, id="id", time="year", g="g")
#' # spec <- cat_label(spec)
cat_label <- function(spec) {

  stopifnot("data" %in% names(spec), "meta" %in% names(spec))
  d <- spec$data
  never_vals <- spec$meta$never_treated_values %||% c(0, Inf)

  # Identify finite, non-never-treated cohorts
  g_raw <- d$.g
  is_nt  <- g_raw %in% never_vals | is.infinite(g_raw)
  finite_gs <- sort(unique(g_raw[!is_nt]))

  n_coh <- length(finite_gs)
  letters_needed <- n_coh + 1L   # last letter goes to NT

  if (letters_needed > length(LETTERS)) {
    warning("More cohorts than letters available; recycling letters.")
  }
  letter_vec <- rep(LETTERS, length.out = letters_needed)

  # Map finite g values to letters
  cohort_map <- stats::setNames(letter_vec[seq_len(n_coh)], as.character(finite_gs))
  nt_letter  <- letter_vec[letters_needed]

  # Assign letters
  d$.cohort_letter <- dplyr::case_when(
    is_nt  ~ nt_letter,
    TRUE   ~ cohort_map[as.character(g_raw)]
  )

  # Canonical g label
  d$.g_label <- ifelse(
    is_nt,
    "g = \u221e",
    paste0("g = ", g_raw)
  )

  # Pretty combined label
  d$.g_pretty <- paste0(d$.g_label, " (", d$.cohort_letter, ")")

  spec$data <- d
  return(spec)
}
