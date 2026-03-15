# ==============================================================================
# Motivating Example: Medicaid Expansion and Hospital Outcomes (DDD Design)
# ==============================================================================
#
# This example demonstrates how to use the catviz package to visualize a
# Difference-in-Difference-in-Differences (DDD) design with staggered adoption.
#
# RESEARCH QUESTION:
# What is the effect of Medicaid expansion on hospital outcomes, comparing
# non-profit hospitals (treatment subgroup) to for-profit hospitals (control
# subgroup) in states that expanded Medicaid versus states that did not?
#
# DATA STRUCTURE:
# - Unit of analysis: Hospitals (identified by CCN number)
# - Time dimension: Years (panel data)
# - Treatment: State-level Medicaid expansion (staggered adoption)
# - Subgroup: Hospital ownership type (non-profit vs. for-profit)
#
# KEY VARIABLES:
# - ccn_number: Hospital identifier
# - year: Calendar year
# - g: First year state expanded Medicaid (Inf = never expanded)
# - p: Subgroup indicator (1 = non-profit, 0 = for-profit)
# - state_x: State name (treatment assignment level)
#
# ==============================================================================

# ==============================================================================
# STEP 1: Setup and Load Packages
# ==============================================================================

# Clear workspace for clean start
rm(list = ls())

# Load package development tools
library(devtools)

# Navigate to catviz package directory
# IMPORTANT: Update this path to match your catviz location!
setwd("C:/Users/victo/OneDrive/Documents/catviz")

# Load the catviz package (loads all updated R files)
cat("Loading catviz package...\n")
load_all()

# Load required packages
library(catviz)      # Our package for visualizing causal assignment trees
library(dplyr)       # Data manipulation
library(tidyr)       # Data tidying
library(readr)       # Reading CSV files
library(janitor)     # Cleaning variable names
library(ggplot2)     # Plotting (used internally by catviz)

cat("✓ All packages loaded successfully!\n\n")

# ==============================================================================
# STEP 2: Load and Prepare Data
# ==============================================================================

cat("Loading Medicaid expansion data...\n")

# Load the dataset
final_med <- read_csv("final_med.csv", show_col_types = FALSE) %>%
  clean_names()  # Convert all column names to lowercase with underscores

cat("✓ Data loaded successfully!\n")
cat("  - Dimensions:", nrow(final_med), "rows ×", ncol(final_med), "columns\n\n")

# Check column names
cat("Column names in dataset:\n")
print(names(final_med))
cat("\n")

# --- IMPORTANT: Data Requirements ---
# Your dataset MUST contain these columns:
#   - ccn_number: Unique hospital identifier
#   - year: Time variable
#   - g: First year of Medicaid expansion for the state (use Inf for never-treated)
#   - p: Subgroup indicator (1 = non-profit, 0 = for-profit)
#   - state_x: State name (or state identifier)
#
# If your columns have different names, rename them like this:
# final_med <- final_med %>%
#   rename(
#     ccn_number = old_hospital_id_name,
#     state_x = old_state_name,
#     g = treatment_year,
#     p = nonprofit_indicator
#   )

# ==============================================================================
# STEP 3: Explore Treatment Structure
# ==============================================================================

cat("========================================\n")
cat("DATA EXPLORATION\n")
cat("========================================\n\n")

# Number of unique hospitals
n_hospitals <- n_distinct(final_med$ccn_number)
cat("Number of hospitals:", n_hospitals, "\n")

# Number of unique states
n_states <- n_distinct(final_med$state_x)
cat("Number of states:", n_states, "\n")

# Time coverage
time_range <- range(final_med$year, na.rm = TRUE)
cat("Years covered:", time_range[1], "to", time_range[2], "\n\n")

# Treatment cohorts (states' first expansion years)
cat("Treatment cohorts (Medicaid expansion years):\n")
treatment_cohorts <- final_med %>%
  distinct(state_x, g) %>%
  group_by(g) %>%
  summarise(n_states = n(), .groups = "drop") %>%
  arrange(g)
print(treatment_cohorts)
cat("\n")

# Subgroup distribution
cat("Subgroup distribution (p):\n")
subgroup_dist <- final_med %>%
  distinct(ccn_number, p) %>%
  count(p, name = "n_hospitals") %>%
  mutate(
    type = case_when(
      p == 1 ~ "Non-profit (p=1)",
      p == 0 ~ "For-profit (p=0)",
      TRUE ~ "Other"
    )
  )
print(subgroup_dist)
cat("\n")

# ==============================================================================
# STEP 4: Create Causal Assignment Tree Specification
# ==============================================================================

cat("========================================\n")
cat("CREATING DDD SPECIFICATION\n")
cat("========================================\n\n")

cat("Building causal assignment tree for DDD design...\n")

# Create the CAT specification
# This tells catviz how to structure the tree for your analysis
spec <- cat_spec(
  data     = final_med,
  id       = "ccn_number",      # Hospital identifier
  time     = "year",            # Time variable
  g        = "g",               # First treatment year (state-level)
  subgroup = "p",               # Subgroup for DDD (non-profit vs. for-profit)
  group_id = "state_x"          # Treatment assignment level (state)
)

cat("✓ Specification created successfully!\n\n")

# Add human-readable labels to the specification
spec <- cat_label(spec)

# ==============================================================================
# STEP 5: View Summary Statistics
# ==============================================================================

cat("========================================\n")
cat("SUMMARY STATISTICS\n")
cat("========================================\n\n")

# Display counts by cohort and subgroup
cat("Counts by treatment cohort and subgroup:\n")
cat_counts(spec)
cat("\n")

# ==============================================================================
# STEP 6: Create and Save the DDD Tree Visualization
# ==============================================================================

cat("========================================\n")
cat("GENERATING DDD TREE VISUALIZATION\n")
cat("========================================\n\n")

cat("Creating DDD causal assignment tree...\n")
cat("(This shows the structure of your staggered DDD design)\n\n")

# Create output directory for plots
dir.create("R/man/figures", recursive = TRUE, showWarnings = FALSE)

# Generate the DDD tree plot
# This visualizes:
#   - All treatment cohorts (states grouped by expansion year)
#   - Never-treated states
#   - Subgroup splits (non-profit vs. for-profit) within each cohort
p_ddd <- cat_plot_ddd(
  spec = spec,
  counts = TRUE,  # Include sample sizes in the tree
  save_plot = "R/man/figures/medicaid_ddd_tree.png"
)

cat("✓ DDD tree visualization created!\n")
cat("  Saved to: R/man/figures/medicaid_ddd_tree.png\n\n")

# Display the plot in RStudio
print(p_ddd)

# ==============================================================================
# STEP 7: Interpretation Guide
# ==============================================================================

cat("========================================\n")
cat("INTERPRETING YOUR DDD TREE\n")
cat("========================================\n\n")

cat("Your DDD tree shows:\n\n")

cat("1. ROOT NODE (All Units):\n")
cat("   - Total number of hospitals in your dataset\n\n")

cat("2. FIRST LEVEL BRANCHES:\n")
cat("   - 'Treated Cohorts': States that expanded Medicaid\n")
cat("   - 'Never-Treated (g=∞)': States that never expanded\n\n")

cat("3. COHORT NODES (Second Level):\n")
cat("   - Each cohort represents states that expanded in the same year\n")
cat("   - Labeled as 'g = YYYY' (e.g., g = 2014, g = 2015, etc.)\n")
cat("   - Letter labels (A, B, C...) are assigned chronologically\n\n")

cat("4. LEAF NODES (Third Level):\n")
cat("   - Each cohort splits into TWO subgroups:\n")
cat("     • Q = 1: Non-profit hospitals (treatment subgroup)\n")
cat("     • Q = 0: For-profit hospitals (control subgroup)\n")
cat("   - These subgroups enable the DDD comparison\n\n")

cat("5. SAMPLE SIZES:\n")
cat("   - Numbers in parentheses show hospital counts\n")
cat("   - Verify these match your expectations\n\n")

# ==============================================================================
# STEP 8: What the DDD Estimator Does
# ==============================================================================

cat("========================================\n")
cat("HOW DDD WORKS IN THIS CONTEXT\n")
cat("========================================\n\n")

cat("The DDD estimator answers:\n")
cat("'Did Medicaid expansion affect non-profit hospitals differently\n")
cat(" than for-profit hospitals, relative to the same comparison in\n")
cat(" never-treated states?'\n\n")

cat("For each treatment cohort g at time t, DDD computes:\n\n")
cat("  ATT(g,t) = [Outcome(Non-profit, Treated) - Outcome(For-profit, Treated)]\n")
cat("           - [Outcome(Non-profit, Control)  - Outcome(For-profit, Control)]\n\n")

cat("This triple difference removes:\n")
cat("  1. Time-invariant differences between non-profit and for-profit hospitals\n")
cat("  2. Common time shocks affecting all hospitals\n")
cat("  3. Differential trends between hospital types that are common to all states\n\n")

# ==============================================================================
# STEP 9: Next Steps for Analysis
# ==============================================================================

cat("========================================\n")
cat("NEXT STEPS FOR YOUR ANALYSIS\n")
cat("========================================\n\n")

cat("After visualizing your DDD design with catviz:\n\n")

cat("1. ESTIMATION:\n")
cat("   Use a DDD estimation package like:\n")
cat("   - dddid (R package for triple-difference)\n")
cat("   - did package with subgroup indicators\n")
cat("   - Manual regression with state × subgroup × post interactions\n\n")

cat("2. VERIFY PARALLEL TRENDS:\n")
cat("   Check that non-profit vs. for-profit differences evolved similarly\n")
cat("   in treated and control states before expansion\n\n")

cat("3. ESTIMATE ATT(g,t):\n")
cat("   Obtain group-time average treatment effects for each cohort\n\n")

cat("4. AGGREGATE:\n")
cat("   Combine cohort-specific effects using appropriate weights\n\n")

cat("5. INFERENCE:\n")
cat("   Use cluster-robust standard errors at the state level\n")
cat("   Consider multiplier bootstrap for valid inference\n\n")

# ==============================================================================
# BONUS: Single-Treatment DDD (if applicable)
# ==============================================================================

cat("========================================\n")
cat("NOTE: SINGLE-TREATMENT DDD\n")
cat("========================================\n\n")

cat("If your data has ONLY ONE treatment cohort (e.g., all states\n")
cat("expanded Medicaid in the same year), the DDD design simplifies:\n\n")

cat("Example code for single-treatment DDD:\n")
cat("---------------------------------------\n")
cat("# Filter to one treatment year and never-treated\n")
cat("single_treat_data <- final_med %>%\n")
cat("  filter(g %in% c(2014, Inf))  # Only 2014 cohort + never-treated\n\n")

cat("# Create specification (same as before)\n")
cat("spec_single <- cat_spec(\n")
cat("  data = single_treat_data,\n")
cat("  id = 'ccn_number',\n")
cat("  time = 'year',\n")
cat("  g = 'g',\n")
cat("  subgroup = 'p',\n")
cat("  group_id = 'state_x'\n")
cat(")\n\n")

cat("# Plot (will show simpler tree with one cohort)\n")
cat("p_single <- cat_plot_ddd(spec_single, counts = TRUE)\n")
cat("print(p_single)\n\n")

cat("In this case:\n")
cat("  - Only ONE treatment cohort appears in the tree\n")
cat("  - Comparison is between treated states and never-treated states\n")
cat("  - Subgroup splits still enable triple-differencing\n\n")

# ==============================================================================
# Summary and File Outputs
# ==============================================================================

cat("========================================\n")
cat("ANALYSIS COMPLETE!\n")
cat("========================================\n\n")

cat("Generated files:\n")
cat("  ✓ R/man/figures/medicaid_ddd_tree.png\n\n")

cat("Verification checklist:\n")
cat("  □ Tree shows all treatment cohorts (expansion years)\n")
cat("  □ Each cohort has Q = 1 (non-profit) and Q = 0 (for-profit) leaves\n")
cat("  □ Never-treated group appears on the right\n")
cat("  □ No overlapping nodes\n")
cat("  □ Sample sizes are correct and add up\n")
cat("  □ Letter labels are assigned chronologically\n\n")

cat("Your DDD tree is ready! Use it to:\n")
cat("  • Explain your research design to readers\n")
cat("  • Verify treatment structure before estimation\n")
cat("  • Communicate which units serve as controls\n")
cat("  • Show the complexity of your staggered design\n\n")

cat("Happy analyzing! \n")
