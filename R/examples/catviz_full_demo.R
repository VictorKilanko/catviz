# ==============================================================================
# catviz FULL DEMONSTRATION SCRIPT
# Shows every function for DiD, CSDiD, and DDD designs
# Author: Victor Kilanko
# ==============================================================================
# DATA USED:
#   - Simulated data (2x2 DiD, CSDiD): generated inline
#   - Medicaid hospital panel (DDD): medicaid_ddd.csv (in this folder)
#     Variables: hospital_id, year, state, g (expansion year or Inf), p (subgroup)
# ==============================================================================

# ── 0. Setup ──────────────────────────────────────────────────────────────────
# Load catviz (choose ONE of the two lines below)
# If installed from CRAN / GitHub:
library(catviz)
# If developing locally:
# devtools::load_all("C:/Users/victo/OneDrive/Documents/catviz")

library(dplyr)
library(tidyr)
library(ggplot2)

# Set output folder for saved plots
outdir <- file.path(dirname(rstudioapi::getActiveDocumentContext()$path), "output")
dir.create(outdir, showWarnings = FALSE)

cat("catviz Full Demo — Victor Kilanko\n")
cat(rep("=", 60), "\n", sep = "")

# ==============================================================================
# SECTION 1: 2×2 DiD (standard, one treatment cohort)
# ==============================================================================
cat("\n[1] 2×2 DiD Design\n")

set.seed(1)
df_did <- data.frame(
  hospital_id = rep(paste0("H", 1:40), each = 6),
  year        = rep(2016:2021, 40),
  g           = c(rep(2019, 120), rep(Inf, 120))   # 20 treated, 20 control hospitals
)
df_did$outcome <- rnorm(nrow(df_did), mean = 10 + (df_did$year >= df_did$g & is.finite(df_did$g)) * 2)

# 1a. Build spec
spec_did <- cat_spec(
  data = df_did,
  id   = "hospital_id",
  time = "year",
  g    = "g"
)

# 1b. Label cohorts
spec_did <- cat_label(spec_did)
cat("  Cohort letter assignments:\n")
print(spec_did$data %>% distinct(.g, .cohort_letter, .g_pretty) %>% arrange(.g))

# 1c. Count nodes
cat("\n  Node counts:\n")
print(cat_counts(spec_did))

# 1d. Plot tree
p_did <- cat_plot_tree(spec_did, counts = TRUE)
print(p_did)
cat_save_png(p_did, file.path(outdir, "did_tree.png"), width = 10, height = 6)

# 1e. Grayscale
p_did_gray <- cat_plot_tree(spec_did, counts = TRUE, grayscale = TRUE)
cat_save_png(p_did_gray, file.path(outdir, "did_tree_grayscale.png"), width = 10, height = 6)

# 1f. ATT equation
cat("\n  ATT equation (DID):\n")
# DID is a special case; show manually
eq <- cat_att_equation("drddd")   # the DDD equation reduces to DiD for one cohort
cat("  ", eq$text, "\n")

cat("\n  [Done] 2×2 DiD\n")

# ==============================================================================
# SECTION 2: CSDiD — staggered adoption, no subgroup
# ==============================================================================
cat("\n[2] CSDiD Design (Callaway–Sant'Anna staggered adoption)\n")

set.seed(2)
states  <- paste0("S", 1:20)
years   <- 2013:2022
adopt_g <- c(2015, 2017, 2019, 2021, Inf)   # 5 cohorts including never-treated

state_df <- tibble(
  state = states,
  g     = sample(adopt_g, length(states), replace = TRUE)
)
hospitals_cs <- state_df %>%
  mutate(hospital_id = purrr::map(state, ~paste0(.x, "_H", 1:5))) %>%
  tidyr::unnest(hospital_id)

df_cs <- tidyr::expand_grid(hospital_id = hospitals_cs$hospital_id, year = years) %>%
  left_join(hospitals_cs, by = "hospital_id") %>%
  mutate(outcome = rnorm(n(), 8 + (year >= g & is.finite(g)) * 1.5))

# 2a. Build spec (no subgroup)
spec_cs <- cat_spec(df_cs, id = "hospital_id", time = "year", g = "g")
spec_cs <- cat_label(spec_cs)

cat("  Cohort letter assignments:\n")
print(spec_cs$data %>% distinct(.g, .cohort_letter, .g_pretty) %>% arrange(.g))

cat("\n  Node counts:\n")
print(cat_counts(spec_cs))

# 2b. CSDiD tree plot
p_cs <- cat_plot_tree(spec_cs, counts = TRUE)
print(p_cs)
cat_save_png(p_cs, file.path(outdir, "csdid_tree.png"), width = 14, height = 7)

p_cs_gray <- cat_plot_tree(spec_cs, grayscale = TRUE)
cat_save_png(p_cs_gray, file.path(outdir, "csdid_tree_grayscale.png"), width = 14, height = 7)

# 2c. Pretrend diagnostic
cat("\n  Pretrend diagnostic (CSDID):\n")
diag_cs <- cat_diag(spec_cs, outcome = "outcome", method = "csdid")
cat_save_png(diag_cs$plot, file.path(outdir, "csdid_pretrend.png"))

# 2d. ATT equation
cat("\n  ATT equation (CSDiD, p=1 subgroup):\n")
eq_cs <- cat_att_equation("csdid", subgroup_value = 1)
cat("  ", eq_cs$text, "\n")

cat("\n  [Done] CSDiD\n")

# ==============================================================================
# SECTION 3: DDD / DR-DDD — staggered adoption × binary subgroup
# Using REAL Medicaid hospital data
# ==============================================================================
cat("\n[3] DDD / DR-DDD Design — Medicaid Hospital Panel\n")
cat("  Loading medicaid_ddd.csv ...\n")

# Locate data file relative to this script
script_dir <- tryCatch(
  dirname(rstudioapi::getActiveDocumentContext()$path),
  error = function(e) "C:/Users/victo/OneDrive/Documents/catviz/R/examples"
)
med_path <- file.path(script_dir, "medicaid_ddd.csv")

if (!file.exists(med_path)) {
  stop("Cannot find medicaid_ddd.csv. Expected at: ", med_path,
       "\nPlease run subset_med.R first or adjust the path.")
}

med <- read.csv(med_path)

# Verify key columns
cat("  Columns:", paste(names(med), collapse=", "), "\n")
cat("  Rows:", nrow(med), " | Hospitals:", length(unique(med$hospital_id)),
    " | States:", length(unique(med$state)), "\n")
cat("  g values:", paste(sort(unique(med$g)), collapse=", "), "\n")
cat("  p values:", paste(unique(med$p), collapse=", "), "\n")

# 3a. Build DDD spec
spec_ddd <- cat_spec(
  data     = med,
  id       = "hospital_id",
  time     = "year",
  g        = "g",
  subgroup = "p",           # p = nonprofit (1) vs. for-profit (0)
  group_id = "state"
)
spec_ddd <- cat_label(spec_ddd)

cat("\n  Cohort letter assignments:\n")
print(spec_ddd$data %>% distinct(.g, .cohort_letter, .g_pretty) %>% arrange(.g))

cat("\n  Node counts:\n")
print(cat_counts(spec_ddd))

# 3b. DDD tree
p_ddd <- cat_plot_tree(spec_ddd, counts = TRUE)
print(p_ddd)
cat_save_png(p_ddd, file.path(outdir, "ddd_tree_medicaid.png"), width = 16, height = 9)

p_ddd_gray <- cat_plot_tree(spec_ddd, grayscale = TRUE)
cat_save_png(p_ddd_gray, file.path(outdir, "ddd_tree_medicaid_grayscale.png"), width = 16, height = 9)

# 3c. ATT equation (DR-DDD)
cat("\n  ATT equation (DR-DDD):\n")
eq_ddd <- cat_att_equation("drddd")
cat("  Text:", eq_ddd$text, "\n")
cat("  LaTeX:", eq_ddd$tex, "\n")
cat("  Note:", eq_ddd$note, "\n")

# 3d. ATT equation (CSDiD within subgroup)
cat("\n  ATT equation (CSDiD within p=1 subgroup):\n")
eq_cs1 <- cat_att_equation("csdid", subgroup_value = 1)
cat("  Text:", eq_cs1$text, "\n")

cat("\n  ATT equation (CSDiD within p=0 subgroup):\n")
eq_cs0 <- cat_att_equation("csdid", subgroup_value = 0)
cat("  Text:", eq_cs0$text, "\n")

# 3e. Covariate balance
if ("charity_care" %in% names(med)) {
  cat("\n  Covariate balance (charity_care):\n")
  bal <- cat_balance_table(spec_ddd, covariates = "charity_care", by = "node")
  print(bal)
  p_bal <- cat_balance_plot(bal)
  print(p_bal)
  cat_save_png(p_bal, file.path(outdir, "ddd_balance.png"))
}

# 3f. DR-DDD Pretrend diagnostic
if ("charity_care" %in% names(med)) {
  cat("\n  Pretrend diagnostic (DR-DDD, outcome = charity_care):\n")
  diag_ddd <- cat_diag(spec_ddd, outcome = "charity_care", method = "drddd",
                        pre_window = -5:-1)
  cat_save_png(diag_ddd$plot, file.path(outdir, "ddd_pretrend.png"))
}

cat("\n  [Done] DDD\n")

# ==============================================================================
# SECTION 4: Design blueprint functions
# ==============================================================================
cat("\n[4] Design Blueprints (cat_design_*)\n")

bp_did   <- cat_design_did()
bp_cs    <- cat_design_csdid(generate_cohort_labels(c(2015, 2017, 2019, 2021)))
bp_ddd   <- cat_design_ddd(generate_cohort_labels(c(2015, 2017, 2019)))

cat("  DiD blueprint root:", bp_did$root, "\n")
cat("  CSDiD blueprint branches:", length(bp_cs$branches), "\n")
cat("  DDD blueprint branches:", length(bp_ddd$branches), "\n")
cat("  generate_cohort_labels example:", paste(generate_cohort_labels(c(2015,2017,2019)), collapse=", "), "\n")

# ==============================================================================
# SECTION 5: Summary
# ==============================================================================
cat("\n", rep("=", 60), "\n", sep = "")
cat("SUMMARY — all output files saved to:\n  ", outdir, "\n\n")
cat("Files generated:\n")
for (f in list.files(outdir)) cat("  ✓", f, "\n")

cat("\nAll catviz functions demonstrated successfully!\n")
