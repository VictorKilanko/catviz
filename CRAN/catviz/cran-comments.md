# CRAN Submission Comments — catviz 0.1.0 (resubmission 3)

## Resubmission — in response to Uwe Ligges' request (2026-03-27)

The previous submission contained a typographic error in one DOI:

- **Wrong:** `<doi:10.1016/j.jeconom.2020.06.014>` (returned HTTP 404)
- **Corrected:** `<doi:10.1016/j.jeconom.2020.06.003>` (resolves correctly)

Both DOIs in DESCRIPTION are now verified and resolve:

- Callaway and Sant'Anna (2021): `<doi:10.1016/j.jeconom.2020.12.001>` ✓
- Sant'Anna and Zhao (2020): `<doi:10.1016/j.jeconom.2020.06.003>` ✓

In addition, `\examples{}` blocks have been added to all exported functions
that were previously missing them. All examples use simulated inline data and
pass `R CMD check --as-cran`.

## Test environments

* Windows 11, R 4.4.3 (local, TinyTeX)

## R CMD check results

0 errors | 0 warnings | 1 note

The NOTE is "unable to verify current time" — a known network/environment
issue on this machine; it is unrelated to the package.

(A "LaTeX errors when creating PDF version" WARNING appears locally due to
a TinyTeX `rerunfilecheck` first-pass message, but the PDF builds successfully —
`checking PDF version of manual without index ... OK` — and this is not expected
on CRAN's servers.)

## Notes for CRAN reviewers

* This is resubmission 3, correcting the typo in the Sant'Anna and Zhao DOI.
* The package provides visualization tools for causal inference designs
  (DiD, CSDiD, DDD). It does not download data from external URLs.
* All example data are simulated inline in examples and tests.
* The `%||%` operator is imported from `rlang` (listed in Imports).
