library(testthat)
library(catviz)

# Minimal test data
make_df <- function(subgroup = FALSE) {
  df <- data.frame(
    id   = rep(1:6, each = 4),
    year = rep(2017:2020, 6),
    g    = c(rep(2018, 8), rep(2019, 8), rep(Inf, 8))
  )
  if (subgroup) df$p <- rep(c(0L, 1L), 12)
  df
}

test_that("cat_spec returns a cat_spec object", {
  spec <- cat_spec(make_df(), id = "id", time = "year", g = "g")
  expect_s3_class(spec, "cat_spec")
  expect_true(all(c("data", "meta") %in% names(spec)))
})

test_that("cat_spec adds internal columns", {
  spec <- cat_spec(make_df(), id = "id", time = "year", g = "g")
  cols <- names(spec$data)
  expect_true(all(c(".id", ".time", ".g", ".NT", ".NYT", ".node") %in% cols))
})

test_that("never-treated indicator is correct", {
  spec <- cat_spec(make_df(), id = "id", time = "year", g = "g")
  d <- spec$data
  expect_true(all(d$.NT[d$g == Inf] == 1L))
  expect_true(all(d$.NT[is.finite(d$g)] == 0L))
})

test_that("cat_spec errors on missing columns", {
  expect_error(
    cat_spec(make_df(), id = "bad_col", time = "year", g = "g"),
    regexp = NULL
  )
})

test_that("cat_label assigns letters dynamically", {
  spec <- cat_spec(make_df(), id = "id", time = "year", g = "g")
  spec <- cat_label(spec)
  d    <- spec$data
  expect_true(".cohort_letter" %in% names(d))
  letters_used <- sort(unique(d$.cohort_letter))
  # 2 finite cohorts (A, B) + NT (C)
  expect_equal(letters_used, c("A", "B", "C"))
})

test_that("cat_counts returns a tibble with .node column", {
  spec <- cat_spec(make_df(), id = "id", time = "year", g = "g")
  ct   <- cat_counts(spec)
  expect_true(is.data.frame(ct))
  expect_true(".node" %in% names(ct))
  expect_true("n" %in% names(ct))
})

test_that("cat_plot_tree dispatches correctly for CSDID", {
  spec <- cat_spec(make_df(), id = "id", time = "year", g = "g")
  p <- cat_plot_tree(spec)
  expect_s3_class(p, "ggplot")
})

test_that("cat_plot_tree dispatches correctly for DDD", {
  spec <- cat_spec(make_df(TRUE), id = "id", time = "year", g = "g", subgroup = "p")
  p <- cat_plot_tree(spec)
  expect_s3_class(p, "ggplot")
})

test_that("cat_plot_tree grayscale option works", {
  spec <- cat_spec(make_df(), id = "id", time = "year", g = "g")
  p <- cat_plot_tree(spec, grayscale = TRUE)
  expect_s3_class(p, "ggplot")
})

test_that("cat_att_equation returns expected structure", {
  eq <- cat_att_equation("drddd")
  expect_true(all(c("text", "tex", "nodes", "note") %in% names(eq)))
})
