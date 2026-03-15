# ==============================================================================
# Psychedelics Deprioritization and Crime in California: CSDiD Design
# Using the catviz Package to Visualize Staggered Treatment Adoption
# ==============================================================================
#
# This script demonstrates how to use the catviz package to visualize a
# Callaway-Sant'Anna Difference-in-Differences (CSDiD) design with staggered
# treatment adoption.
#
# RESEARCH QUESTION:
# What is the effect of psychedelics deprioritization policies on crime rates
# in California cities that adopted these policies at different times?
#
# DATA STRUCTURE:
# - Unit of analysis: Cities
# - Time dimension: Monthly panel data (2017-2023)
# - Treatment: City-level psychedelics deprioritization (staggered adoption)
# - Outcomes: Violent crime and property crime rates per 100,000 population
#
# TREATMENT TIMELINE:
# - Oakland: June 2019
# - Santa Cruz: January 2020
# - Arcata: October 2021
# - San Francisco: September 2022
# - Berkeley: July 2023
# - All other cities: Never treated (control group)
#
# ==============================================================================

# ==============================================================================
# STEP 1: Setup and Load Packages
# ==============================================================================

# Clear workspace for clean start
rm(list = ls())

# Load package development tools (for catviz)
library(devtools)

# Navigate to catviz package directory
# IMPORTANT: Update this path to match your catviz location!
setwd("C:/Users/victo/OneDrive/Documents/catviz")

# Load the catviz package
cat("Loading catviz package...\n")
load_all()

# Load required packages
library(catviz)      # Causal assignment tree visualization
library(dplyr)       # Data manipulation
library(tidyr)       # Data tidying
library(ggplot2)     # Plotting

cat("✓ All packages loaded successfully!\n\n")

# ==============================================================================
# STEP 2: Set Working Directory and Load Data
# ==============================================================================

# Navigate to your data directory
setwd("C:/Users/victo/OneDrive/Documents/Dissertation/Psy/R6")

cat("Loading psychedelics policy and crime data...\n")

# Load the dataset
mydata <- read.csv("chapter1log.csv")

cat("✓ Data loaded successfully!\n")
cat("  - Dimensions:", nrow(mydata), "rows ×", ncol(mydata), "columns\n\n")

# ==============================================================================
# STEP 3: Prepare Analysis Dataset
# ==============================================================================

cat("Preparing analysis dataset...\n")

# Select relevant variables
analysis_df <- mydata %>%
  select(
    Year,                              # Calendar year
    Month,                             # Calendar month
    City,                              # City name (unit identifier)
    Violent_per_100k,                  # Violent crime rate (outcome)
    Property_per_100k,                 # Property crime rate (outcome)
    Female.Veterans,                   # Control variable
    Population.Density,                # Control variable
    Gini.Index..Income.Inequality.     # Control variable
  )

# Create a proper date variable (YYYY-MM-01 format)
analysis_df <- analysis_df %>%
  mutate(Date = as.Date(paste(Year, Month, "01", sep = "-")))

cat("✓ Analysis dataset prepared\n")
cat("  - Variables selected:", ncol(analysis_df), "\n")
cat("  - Date range:", min(analysis_df$Date), "to", max(analysis_df$Date), "\n\n")

# ==============================================================================
# STEP 4: Define Treatment Structure
# ==============================================================================

cat("Defining treatment timeline...\n")

# Create treatment dates table
# This specifies when each city adopted psychedelics deprioritization
treatment_dates <- tibble(
  City  = c("Oakland", "Santa Cruz", "Arcata", "San Francisco", "Berkeley"),
  Tdate = as.Date(c(
    "2019-06-01",  # Oakland: June 2019
    "2020-01-01",  # Santa Cruz: January 2020
    "2021-10-01",  # Arcata: October 2021
    "2022-09-01",  # San Francisco: September 2022
    "2023-07-01"   # Berkeley: July 2023
  ))
)

cat("\nTreated cities and adoption dates:\n")
print(treatment_dates)
cat("\n")

# Merge treatment dates with main dataset
analysis_df <- analysis_df %>%
  left_join(treatment_dates, by = "City")

# For cities without treatment dates (never-treated), set Tdate to Infinity
# This tells catviz these cities never receive treatment
analysis_df <- analysis_df %>%
  mutate(
    Tdate = if_else(is.na(Tdate), as.Date(Inf, origin = "1970-01-01"), Tdate)
  )

cat("✓ Treatment structure defined\n")
cat("  - Treated cities: 5\n")
cat("  - Never-treated cities:", 
    length(unique(analysis_df$City[is.infinite(as.numeric(analysis_df$Tdate))])), "\n\n")

# ==============================================================================
# STEP 5: Explore the Data
# ==============================================================================

cat("========================================\n")
cat("DATA EXPLORATION\n")
cat("========================================\n\n")

# Number of unique cities
n_cities <- n_distinct(analysis_df$City)
cat("Total number of cities:", n_cities, "\n")

# Treatment cohorts
cat("\nTreatment cohorts:\n")
cohort_summary <- analysis_df %>%
  distinct(City, Tdate) %>%
  mutate(
    Cohort = if_else(is.infinite(as.numeric(Tdate)), "Never-treated", as.character(Tdate))
  ) %>%
  count(Cohort, name = "n_cities") %>%
  arrange(Cohort)
print(cohort_summary)
cat("\n")

# Time periods
time_summary <- analysis_df %>%
  summarise(
    first_month = min(Date),
    last_month = max(Date),
    total_months = n_distinct(Date)
  )
cat("Time coverage:\n")
cat("  - First month:", as.character(time_summary$first_month), "\n")
cat("  - Last month:", as.character(time_summary$last_month), "\n")
cat("  - Total months:", time_summary$total_months, "\n\n")

# ==============================================================================
# STEP 6: Create Causal Assignment Tree Specification
# ==============================================================================

cat("========================================\n")
cat("CREATING CSDID SPECIFICATION\n")
cat("========================================\n\n")

cat("Building causal assignment tree for CSDiD design...\n")

# Create the CAT specification
# This tells catviz how to structure the tree for your CSDiD analysis
spec <- cat_spec(
  data     = analysis_df,
  id       = "City",        # Unit identifier (city name)
  time     = "Date",        # Time variable (monthly dates)
  g        = "Tdate",       # First treatment date (cohort identifier)
  group_id = "City"         # Treatment assignment level (city)
)

cat("✓ Specification created successfully!\n\n")

# Add human-readable labels to the specification
spec <- cat_label(spec)

# ==============================================================================
# STEP 7: View Summary Statistics
# ==============================================================================

cat("========================================\n")
cat("SUMMARY STATISTICS\n")
cat("========================================\n\n")

# Display counts by treatment cohort
cat("Counts by treatment cohort:\n")
cat_counts(spec)
cat("\n")

# ==============================================================================
# STEP 8: Create and Save the CSDiD Tree Visualization
# ==============================================================================

cat("========================================\n")
cat("GENERATING CSDID TREE VISUALIZATION\n")
cat("========================================\n\n")

cat("Creating CSDiD causal assignment tree...\n")
cat("(This shows the structure of your staggered adoption design)\n\n")

# Create output directory for plots
dir.create("figures", showWarnings = FALSE)

# Generate the CSDiD tree plot
# This visualizes:
#   - All treatment cohorts (cities grouped by adoption date)
#   - Never-treated cities (control group)
#   - Sample sizes for each cohort
p_csdid <- cat_plot_csdid(
  spec = spec,
  counts = TRUE,  # Include sample sizes in the tree
  save_plot = "figures/psychedelics_csdid_tree.png"
)

cat("✓ CSDiD tree visualization created!\n")
cat("  Saved to: figures/psychedelics_csdid_tree.png\n\n")

# Display the plot in RStudio
print(p_csdid)

# ==============================================================================
# STEP 9: Interpretation Guide
# ==============================================================================

cat("========================================\n")
cat("INTERPRETING YOUR CSDID TREE\n")
cat("========================================\n\n")

cat("Your CSDiD tree shows:\n\n")

cat("1. ROOT NODE (All Units):\n")
cat("   - Total number of cities in your dataset (", n_cities, " cities)\n\n", sep = "")

cat("2. FIRST LEVEL BRANCHES:\n")
cat("   - 'Treated Cohorts': Cities that adopted psychedelics deprioritization\n")
cat("   - 'Never-Treated (g=∞)': Cities that never adopted (control group)\n\n")

cat("3. COHORT NODES (Second Level):\n")
cat("   - Each cohort represents cities that adopted at the same time\n")
cat("   - Labeled as 'g = YYYY-MM-DD' (e.g., g = 2019-06-01 for Oakland)\n")
cat("   - Letter labels (A, B, C, D, E) are assigned chronologically\n\n")

cat("4. SAMPLE SIZES:\n")
cat("   - Numbers in parentheses show how many cities are in each cohort\n")
cat("   - Verify these match your expectations\n\n")

# ==============================================================================
# STEP 10: What the CSDiD Estimator Does
# ==============================================================================

cat("========================================\n")
cat("HOW CSDID WORKS IN THIS CONTEXT\n")
cat("========================================\n\n")

cat("The CSDiD estimator answers:\n")
cat("'What was the effect of psychedelics deprioritization on crime rates\n")
cat(" for each cohort of cities that adopted the policy, compared to cities\n")
cat(" that had not yet adopted (or never adopted)?'\n\n")

cat("For each treatment cohort g at time t, CSDiD computes:\n\n")
cat("  ATT(g,t) = E[Crime Rate | Cohort g, Time t, Treated]\n")
cat("           - E[Crime Rate | Not-yet-treated, Time t]\n\n")

cat("This group-time ATT:\n")
cat("  1. Allows treatment effects to vary across cohorts and over time\n")
cat("  2. Uses not-yet-treated cities as clean comparison groups\n")
cat("  3. Avoids bias from differential treatment timing\n\n")

# ==============================================================================
# STEP 11: Next Steps for Analysis
# ==============================================================================

cat("========================================\n")
cat("NEXT STEPS FOR YOUR ANALYSIS\n")
cat("========================================\n\n")

cat("After visualizing your CSDiD design with catviz:\n\n")

cat("1. VERIFY PARALLEL TRENDS:\n")
cat("   Check that treated and control cities had similar crime trends\n")
cat("   before treatment adoption\n\n")

cat("2. ESTIMATE ATT(g,t):\n")
cat("   Use the 'did' package or other CSDiD estimation tools:\n")
cat("   \n")
cat("   library(did)\n")
cat("   result <- att_gt(\n")
cat("     yname = 'Violent_per_100k',\n")
cat("     tname = 'Date',\n")
cat("     idname = 'City',\n")
cat("     gname = 'Tdate',\n")
cat("     data = analysis_df\n")
cat("   )\n\n")

cat("3. AGGREGATE GROUP-TIME EFFECTS:\n")
cat("   Combine cohort-specific effects using appropriate weights\n\n")

cat("4. CONDUCT INFERENCE:\n")
cat("   Use multiplier bootstrap for valid standard errors\n")
cat("   Account for clustering at the city level\n\n")

cat("5. VISUALIZE RESULTS:\n")
cat("   Plot event study estimates\n")
cat("   Show dynamic treatment effects over time\n\n")

# ==============================================================================
# BONUS: Save Summary Information
# ==============================================================================

cat("========================================\n")
cat("SAVING SUMMARY INFORMATION\n")
cat("========================================\n\n")

# Create a summary table
summary_table <- analysis_df %>%
  distinct(City, Tdate) %>%
  mutate(
    Cohort = if_else(
      is.infinite(as.numeric(Tdate)), 
      "Never-treated", 
      as.character(Tdate)
    ),
    Treatment_Status = if_else(
      is.infinite(as.numeric(Tdate)), 
      "Control", 
      "Treated"
    )
  ) %>%
  arrange(Tdate, City)

# Save to CSV
write.csv(summary_table, "figures/treatment_summary.csv", row.names = FALSE)
cat("✓ Treatment summary saved to: figures/treatment_summary.csv\n\n")

# ==============================================================================
# Summary and Completion
# ==============================================================================

cat("========================================\n")
cat("ANALYSIS COMPLETE!\n")
cat("========================================\n\n")

cat("Generated files:\n")
cat("  ✓ figures/psychedelics_csdid_tree.png (CAT visualization)\n")
cat("  ✓ figures/treatment_summary.csv (treatment timeline)\n\n")

cat("Verification checklist:\n")
cat("  □ Tree shows all 5 treatment cohorts\n")
cat("  □ Never-treated group appears on the right\n")
cat("  □ No overlapping nodes\n")
cat("  □ Sample sizes are correct\n")
cat("  □ Letter labels (A-E) are assigned chronologically\n\n")

cat("Your CSDiD tree is ready! Use it to:\n")
cat("  • Explain your research design to readers\n")
cat("  • Verify treatment structure before estimation\n")
cat("  • Communicate which cities serve as controls\n")
cat("  • Show the staggered nature of policy adoption\n\n")

cat("Happy analyzing! 🎉\n")