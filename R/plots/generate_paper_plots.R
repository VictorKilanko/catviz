# =============================================================================
# generate_paper_plots.R
# Generates all 5 figures referenced in Paper.txt using the CURRENT catviz
# source code. Run this script to regenerate plots after any package changes.
#
# Output (saved to this folder):
#   did.png                    - Fig 1: 2x2 DiD CAT
#   csdid.png                  - Fig 2: Generic CSDiD (staggered adoption)
#   ddd.png                    - Fig 3: Generic DDD (cohorts 2015-2023)
#   psychedelics_csdid_tree.png - Fig 4: Psychedelics application (CSDiD)
#   medicaid_ddd_tree.png      - Fig 5: Medicaid application (DDD)
# =============================================================================

library(devtools)
load_all("C:/Users/victo/OneDrive/Documents/catviz")

library(dplyr)
library(tidyr)
library(ggplot2)

outdir <- "C:/Users/vcto/OneDrive/Documents/catviz/R/plots"
outdir <- "C:/Users/victo/OneDrive/Documents/catviz/R/plots"
cat("Output directory:", outdir, "\n\n")

# ─────────────────────────────────────────────────────────────────────────────
# PLOT 1: did.png
# 2x2 DiD CAT — 40 hospitals, 1 treatment cohort (g=2019), control group
# Matches paper caption: "All 100 units split into treated (A) and control (B)"
# ─────────────────────────────────────────────────────────────────────────────
cat("[1/5] Generating did.png ...\n")

set.seed(42)
df_did <- data.frame(
  hospital_id = rep(paste0("H", 1:100), each = 6),
  year        = rep(2016:2021, 100),
  g           = c(rep(2019, 300), rep(Inf, 300))   # 50 treated, 50 control
)

spec_did <- cat_spec(df_did, id = "hospital_id", time = "year", g = "g")
spec_did <- cat_label(spec_did)

p_did <- cat_plot_tree(spec_did, counts = TRUE)
cat_save_png(p_did, file.path(outdir, "did.png"), width = 10, height = 6, dpi = 300)
cat("   Saved: did.png\n")

# ─────────────────────────────────────────────────────────────────────────────
# PLOT 2: csdid.png
# CSDiD CAT — 100 units, 6 treatment cohorts (A-F) + never-treated (G)
# Matches paper caption: "100 units split into treated cohorts (A through F)
#   by first treatment year, plus never-treated group (G)"
# ─────────────────────────────────────────────────────────────────────────────
cat("[2/5] Generating csdid.png ...\n")

set.seed(42)
cohort_g  <- c(2015, 2016, 2017, 2018, 2019, 2020, Inf)
n_per     <- c(10, 10, 10, 10, 10, 10, 40)   # 60 treated, 40 never = 100 total

ids <- unlist(mapply(function(g_val, n) paste0("U", g_val, "_", 1:n),
                     cohort_g, n_per, SIMPLIFY = FALSE))
gs  <- unlist(mapply(function(g_val, n) rep(g_val, n), cohort_g, n_per, SIMPLIFY = FALSE))

df_cs <- tidyr::expand_grid(unit_id = ids, year = 2013:2022) |>
  left_join(data.frame(unit_id = ids, g = gs), by = "unit_id") |>
  mutate(outcome = rnorm(n(), 8))

spec_cs <- cat_spec(df_cs, id = "unit_id", time = "year", g = "g")
spec_cs <- cat_label(spec_cs)

p_cs <- cat_plot_tree(spec_cs, counts = TRUE)
cat_save_png(p_cs, file.path(outdir, "csdid.png"), width = 14, height = 7, dpi = 300)
cat("   Saved: csdid.png\n")

# ─────────────────────────────────────────────────────────────────────────────
# PLOT 3: ddd.png
# DDD CAT — cohorts 2015, 2016, 2019, 2020, 2021, 2023 + never-treated
# Subgroups: Q=1 (treated subgroup) vs Q=0 (control subgroup)
# Matches paper caption: "cohorts 2015 through 2023 split into Q=1 and Q=0"
# ─────────────────────────────────────────────────────────────────────────────
cat("[3/5] Generating ddd.png ...\n")

set.seed(42)
cohort_years <- c(2015, 2016, 2019, 2020, 2021, 2023, Inf)
n_hospitals  <- c(30, 20, 20, 20, 20, 20, 50)  # ~180 total

hosp_list <- mapply(function(g_val, n) {
  data.frame(
    hospital_id = paste0("H_", g_val, "_", 1:n),
    g           = g_val,
    state       = paste0("ST_", g_val),
    p           = rep(c(1L, 0L), length.out = n)
  )
}, cohort_years, n_hospitals, SIMPLIFY = FALSE)

hosp_df <- do.call(rbind, hosp_list)

df_ddd <- tidyr::expand_grid(hospital_id = hosp_df$hospital_id, year = 2012:2025) |>
  left_join(hosp_df, by = "hospital_id") |>
  mutate(outcome = rnorm(n(), 10))

spec_ddd <- cat_spec(df_ddd, id = "hospital_id", time = "year",
                     g = "g", subgroup = "p", group_id = "state")
spec_ddd <- cat_label(spec_ddd)

p_ddd <- cat_plot_tree(spec_ddd, counts = TRUE)
cat_save_png(p_ddd, file.path(outdir, "ddd.png"), width = 16, height = 9, dpi = 300)
cat("   Saved: ddd.png\n")

# ─────────────────────────────────────────────────────────────────────────────
# PLOT 4: psychedelics_csdid_tree.png
# CSDiD tree for the psychedelics application
# 289 California cities, 5 treated cohorts exactly matching the paper:
#   Oakland (June 2019), Santa Cruz (Jan 2020), Arcata (Oct 2021),
#   San Francisco (Sep 2022), Berkeley (Jul 2023)
#   Never-treated: 284 cities
# ─────────────────────────────────────────────────────────────────────────────
cat("[4/5] Generating psychedelics_csdid_tree.png ...\n")

# 5 treated cities with exact adoption months (converted to year-month integer)
# catviz uses numeric g; using integer year-month as proxy (YYYYMM)
treated_cities <- data.frame(
  city_id = c("Oakland", "Santa Cruz", "Arcata", "San Francisco", "Berkeley"),
  g       = c(201906, 202001, 202110, 202209, 202307)
)

set.seed(42)
never_cities <- data.frame(
  city_id = paste0("City_", 1:284),
  g       = Inf
)

all_cities <- rbind(treated_cities, never_cities)

# Monthly data 2017-2023 (84 months)
months <- seq(201701, 202312, by = 1)
# Approximate: just use 2017-2023 as 84 numeric time points
df_psy <- tidyr::expand_grid(city_id = all_cities$city_id,
                              month   = 201701:202312) |>
  filter(month %% 100 >= 1, month %% 100 <= 12) |>
  left_join(all_cities, by = "city_id") |>
  mutate(outcome = rnorm(n(), 5))

spec_psy <- cat_spec(df_psy, id = "city_id", time = "month", g = "g")
spec_psy <- cat_label(spec_psy)

p_psy <- cat_plot_tree(spec_psy, counts = TRUE)
cat_save_png(p_psy, file.path(outdir, "psychedelics_csdid_tree.png"),
             width = 14, height = 7, dpi = 300)
cat("   Saved: psychedelics_csdid_tree.png\n")

# ─────────────────────────────────────────────────────────────────────────────
# PLOT 5: medicaid_ddd_tree.png
# DDD tree for Medicaid application using REAL medicaid_ddd.csv data
# Matches paper exactly: 3,495 hospitals, cohorts 2014-2025, Q=1/0 subgroups
# ─────────────────────────────────────────────────────────────────────────────
cat("[5/5] Generating medicaid_ddd_tree.png ...\n")

med_path <- "C:/Users/victo/OneDrive/Documents/catviz/R/examples/medicaid_ddd.csv"
med <- read.csv(med_path)
cat("   Loaded medicaid_ddd.csv:", nrow(med), "rows,",
    length(unique(med$hospital_id)), "hospitals\n")

spec_med <- cat_spec(med, id = "hospital_id", time = "year",
                     g = "g", subgroup = "p", group_id = "state")
spec_med <- cat_label(spec_med)

p_med <- cat_plot_tree(spec_med, counts = TRUE)
cat_save_png(p_med, file.path(outdir, "medicaid_ddd_tree.png"),
             width = 18, height = 10, dpi = 300)
cat("   Saved: medicaid_ddd_tree.png\n")

# ─────────────────────────────────────────────────────────────────────────────
cat("\n=== Done! Files in", outdir, "===\n")
for (f in list.files(outdir, pattern = "\\.png$")) {
  sz <- file.info(file.path(outdir, f))$size
  cat(sprintf("  %-40s  %d KB\n", f, sz %/% 1024))
}
