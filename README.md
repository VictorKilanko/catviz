# catviz: Causal Assignment Tree Visualization for Staggered DiD, DDD, and Related Designs

**catviz** is an R package for visualizing and understanding **Causal Assignment Trees (CATs)** — hierarchical structures that summarize treatment timing, subgroup composition, and sample classification in **staggered difference-in-differences (CSDID) and staggered DDD like DRDDD** and related causal inference frameworks.

It provides a publication-ready visualization of treated, control, and never-treated groups, along with counts and subgroup summaries, to help researchers verify sample balance and treatment assignment logic.

---

## Installation

You can install the development version of `catviz` directly from GitHub:

```r
# Install devtools if needed
install.packages("devtools")

# Install catviz
devtools::install_github("VictorKilanko/catviz")

# Load the package
library(catviz)

# How it works
library(catviz)
library(dplyr)

set.seed(123)

# Example panel data
example_data <- tibble(
  hospital_id = rep(1:100, each = 10),
  year        = rep(2014:2023, times = 100),
  g           = sample(c(2015, 2016, 2019, 2020, 2021, 2023, Inf),
                       1000, replace = TRUE),
  p           = sample(0:1, 1000, replace = TRUE)
)

# 1. Specify the Causal Assignment Tree
spec <- cat_spec(
  data     = example_data,
  id       = "hospital_id",
  time     = "year",
  g        = "g",
  subgroup = "p"   # omit this line for pure CSDID
)

# 2. (Optional) Label nodes for clarity
spec <- cat_label(spec)

# 3. Counts per node
cat_counts(spec)

# 4. Plot CAT + save plot + save subgroup-by-year table
out <- cat_plot_tree(
  spec,
  save_plot  = "man/figures/CAT_plot_example.png",
  save_table = "man/figures/CAT_summary_example.csv"
)

# Show the plot in RStudio
print(out$plot)

```

## Example output

### 1. CAT plot

Below is the automatically generated **Causal Assignment Tree (CAT)** showing treated, control, and never-treated branches.

![CAT plot example](man/figures/CAT_plot_example.png)

### 2. Treatment-year summary

The accompanying table summarizes the number of treated units by first treatment year and subgroup:

| g    | p_0 | p_1 | Total |
|------|----:|----:|------:|
| 2015 |  56 |  50 |   106 |
| 2016 |  57 |  51 |   108 |
| 2019 |  51 |  55 |   106 |
| 2020 |  54 |  44 |    98 |
| 2021 |  49 |  55 |   104 |
| 2023 |  48 |  54 |   102 |

(The table is also saved automatically at `man/figures/CAT_summary_example.csv`.)

---

## Interpreting the CAT visualization

The **Causal Assignment Tree (CAT)** decomposes the sample into mutually exclusive branches that reflect treatment timing and subgroup classification.  
Each node represents a distinct group of units, with counts (`n`) showing the number of unique units in that category.

**Reading the tree:**
- The root node (“All Groups”) includes all units in the dataset.
- The tree splits into:
  - **Treated Groups:** units with a finite first treatment time `g`.
  - **Never-Treated (g = ∞):** units that never receive treatment.
- Each treated group is then subdivided by **pre-treatment (t < g)** and **post-treatment (t ≥ g)** periods.
- If a subgroup variable `p` is defined (as in a DR-DDD framework), branches also split by subgroup (`p = 0` or `p = 1`).

**Interpretation example:**
In the plot above:
- 100 unique treated units are split into pre- and post-treatment periods.
- 80 units are never treated, with subgroups `p = 0` and `p = 1`.
- Each leaf node (e.g., `(2) t<g, p=1`) shows how many units belong to that treatment-subgroup-period combination.

---

## Interpreting the treatment-year summary

The table lists all first treatment years (`g`) and the number of units in each subgroup:
- Columns `p_0` and `p_1` correspond to the binary subgroup variable.
- The `Total` column is the total number of treated units adopting in that year.

For example:
- In **2016**, 57 units in subgroup 0 and 51 in subgroup 1 were first treated.
- This summary helps verify balance across treatment cohorts and subgroups before estimation.

