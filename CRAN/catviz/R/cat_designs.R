# ============================================================
# cat_designs.R -- Blueprint tree structures for DiD, CSDID, DDD
# ============================================================
#
# This file defines the logical structure (blueprint) for each
# causal assignment tree design. The actual visualization is
# handled by cat_plot.R functions.
#

# ------------------ 2x2 DID TREE ------------------
#' Blueprint for 2x2 Difference-in-Differences Tree
#'
#' Creates the tree structure for standard 2x2 DiD with one
#' treated cohort and one control (never-treated) group.
#'
#' Tree structure:
#'   All Units
#'     |-- Treated (g = g*)
#'     |     |-- Pre (C)
#'     |     +-- Post (D)
#'     +-- Control (g = Inf)
#'           |-- Pre (E)
#'           +-- Post (F)
#'
#' @return A nested list representing the tree structure
#' @examples
#' tree <- cat_design_did()
#' tree$root
#' @export
cat_design_did <- function() {
  list(
    root = "All Units",
    branches = list(
      list(
        label = "Treated (single g)",
        children = list(
          list(label = "Pre (C)"),
          list(label = "Post (D)")
        )
      ),
      list(
        label = "Control (g = Inf)",
        children = list(
          list(label = "Pre (E)"),
          list(label = "Post (F)")
        )
      )
    )
  )
}

# ------------------ CSDID TREE ------------------
#' Blueprint for Callaway-Sant'Anna DiD Tree (Staggered Adoption)
#'
#' Creates the tree structure for CSDiD with multiple treatment
#' cohorts and a never-treated comparison group.
#'
#' Tree structure:
#'   All Units
#'     |-- Never-Treated (g = Inf) (last letter)
#'     +-- Treated Cohorts
#'           |-- g = g1 (A)
#'           |-- g = g2 (B)
#'           |-- g = g3 (C)
#'           +-- ...
#'
#' @param cohort_labels Character vector of cohort labels (e.g., "g = 2015 (A)")
#' @return A nested list representing the tree structure
#' @examples
#' tree <- cat_design_csdid(c("g = 2018 (A)", "g = 2019 (B)"))
#' tree$root
#' @export
cat_design_csdid <- function(cohort_labels) {
  cohort_branches <- lapply(cohort_labels, function(lbl) {
    list(
      label = lbl,
      children = NULL
    )
  })

  list(
    root = "All Units",
    branches = list(
      list(
        label = "Treated Cohorts",
        children = cohort_branches
      ),
      list(
        label = "Never-Treated (g = Inf)",
        children = NULL
      )
    )
  )
}

# ------------------ DDD TREE ------------------
#' Blueprint for Difference-in-Difference-in-Differences Tree
#'
#' Creates the tree structure for DDD with multiple treatment
#' cohorts, each split into treated (Q=1) and untreated (Q=0)
#' subgroups, plus never-treated subgroups.
#'
#' Tree structure:
#'   All Units
#'     |-- Treated Cohorts
#'     |     |-- g = g1
#'     |     |     |-- Q = 1 (A)
#'     |     |     +-- Q = 0 (B)
#'     |     |-- g = g2
#'     |     |     |-- Q = 1 (C)
#'     |     |     +-- Q = 0 (D)
#'     |     +-- ...
#'     +-- Never-Treated (g = Inf)
#'           |-- Q = 1 (penultimate letter)
#'           +-- Q = 0 (last letter)
#'
#' @param cohort_labels Character vector of cohort labels (e.g., "g = 2015")
#' @return A nested list representing the tree structure
#' @examples
#' tree <- cat_design_ddd(c("g = 2018", "g = 2019"))
#' tree$root
#' @export
cat_design_ddd <- function(cohort_labels) {
  cohort_branches <- lapply(cohort_labels, function(lbl) {
    list(
      label = lbl,
      children = list(
        list(label = "Q = 1"),
        list(label = "Q = 0")
      )
    )
  })

  list(
    root = "All Units",
    branches = list(
      list(
        label = "Treated Cohorts",
        children = cohort_branches
      ),
      list(
        label = "Never-Treated (g = Inf)",
        children = list(
          list(label = "Q = 1"),
          list(label = "Q = 0")
        )
      )
    )
  )
}

# ------------------ HELPER FUNCTIONS ------------------

#' Generate cohort labels with letters
#'
#' Creates labeled cohort identifiers in the format "g = YYYY (A)"
#' where letters are assigned chronologically.
#'
#' @param g_values Numeric vector of treatment years/periods
#' @param start_letter Starting letter (default "A")
#' @return Character vector of labeled cohorts
#' @export
#' @examples
#' generate_cohort_labels(c(2015, 2016, 2019))
generate_cohort_labels <- function(g_values, start_letter = "A") {
  g_sorted <- sort(g_values)
  n_cohorts <- length(g_sorted)

  # Generate letters
  letter_idx <- match(start_letter, LETTERS)
  if (is.na(letter_idx)) letter_idx <- 1

  letters_vec <- LETTERS[seq(letter_idx, letter_idx + n_cohorts - 1)]
  if (length(letters_vec) < n_cohorts) {
    warning("More cohorts than letters available; recycling letters")
    letters_vec <- rep(LETTERS, length.out = n_cohorts)
  }

  paste0("g = ", g_sorted, " (", letters_vec, ")")
}

#' Validate tree design structure
#'
#' Checks that a tree design has the required structure
#'
#' @param design A tree design list (from cat_design_*)
#' @return Logical; TRUE if valid, FALSE otherwise
#' @keywords internal
validate_tree_design <- function(design) {
  if (!is.list(design)) return(FALSE)
  if (!"root" %in% names(design)) return(FALSE)
  if (!"branches" %in% names(design)) return(FALSE)
  if (!is.list(design$branches)) return(FALSE)

  # Check each branch has a label
  all_have_labels <- all(sapply(design$branches, function(b) {
    "label" %in% names(b)
  }))

  return(all_have_labels)
}
