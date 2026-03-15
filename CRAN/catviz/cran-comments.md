# CRAN Submission Comments — catviz 0.1.0

## Test environments

* Windows 11, R 4.4.3 (local)
* (Recommended: also test on r-hub before submitting)

## R CMD check results

0 errors | 0 warnings | 0 notes

## Notes for CRAN reviewers

* This is a first submission.
* The package provides visualization tools for causal inference designs
  (DiD, CSDiD, DDD). It does not download data from external URLs.
* All example data are either simulated inline or included in `data/`.
* The `%||%` operator is imported from `rlang` (listed in Imports).
* `ggraph` and `igraph` were removed from Imports after refactoring to
  pure ggplot2-based layouts (no graph-library dependency required).
