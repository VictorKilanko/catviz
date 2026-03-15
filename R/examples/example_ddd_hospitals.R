# =======================================================
# Example: Causal Assignment Tree (DDD or DR-DDD)
# State-level treatment, hospitals nested within states
# =======================================================

# Install once if needed:
# install.packages("devtools")
# devtools::install_github("VictorKilanko/catviz")

library(catviz)
library(dplyr)
library(tidyr)
library(purrr)  # for map()

set.seed(123)

# =======================================================
# 1. Define simulation setup
# =======================================================
states <- sprintf("S%02d", 1:20)    # 20 states
years  <- 2014:2023
N_hosp <- 5                         # 5 hospitals per state

# Assign first treatment year (g) per state
adopt_years <- c(2015, 2016, 2019, 2020, 2021, 2023, Inf)

state_level <- tibble(
  state = states,
  g = sample(adopt_years, length(states), replace = TRUE)
)

# =======================================================
# 2. Create hospitals nested within states
# =======================================================
hospitals <- state_level %>%
  mutate(
    hospital_id = map(state, ~ paste0(.x, "_H", 1:N_hosp))
  ) %>%
  unnest(hospital_id) %>%
  mutate(
    p = sample(0:1, n(), replace = TRUE)  # subgroup (omit for CSDID)
  )

# =======================================================
# 3. Expand to panel structure
# =======================================================
example_data <- expand_grid(
  hospital_id = hospitals$hospital_id,
  year = years
) %>%
  left_join(hospitals, by = "hospital_id") %>%
  arrange(hospital_id, year)

# =======================================================
# 4. Define CAT specification
# =======================================================
# Variables in the CSDID / DR-DDD framework:
# - id: unit of analysis (hospital_id)
# - group_id: grouping or treatment level (state)
# - time: time variable (year)
# - g: first treatment year for the group (state)
# - subgroup: subgroup classification (p), used for DR-DDD only

spec <- cat_spec(
  data      = example_data,
  id        = "hospital_id",
  time      = "year",
  g         = "g",
  subgroup  = "p",         # omit for pure CSDID
  group_id  = "state"      # treatment assigned at state level
)

# Label nodes for clarity
spec <- cat_label(spec)

# =======================================================
# 5. Summaries
# =======================================================
cat_counts(spec)   # counts per node (unit-level by default)

# =======================================================
# 6. Visualization
# =======================================================
dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

# Example 1: Default (unit-level counts)
out_units <- cat_plot_tree(
  spec,
  counts    = TRUE,
  count_by  = "units",   # counts unique hospitals
  save_plot  = "man/figures/CAT_plot_units.png",
  save_table = "man/figures/CAT_summary_units.csv"
)

# Example 2: Observation-level counts
out_obs <- cat_plot_tree(
  spec,
  counts    = TRUE,
  count_by  = "obs",     # counts hospital-year observations
  save_plot  = "man/figures/CAT_plot_obs.png",
  save_table = "man/figures/CAT_summary_obs.csv"
)

# Example 3: Hide counts (just structure)
out_nolabel <- cat_plot_tree(
  spec,
  counts    = FALSE,
  save_plot  = "man/figures/CAT_plot_nolabel.png"
)

# =======================================================
# 7. Display example plot
# =======================================================
print(out_units$plot)

# =======================================================
# 8. Confirm saved outputs
# =======================================================
message("✅ Unit-level plot: man/figures/CAT_plot_units.png")
message("✅ Observation-level plot: man/figures/CAT_plot_obs.png")
message("✅ Summary tables saved in man/figures/")
