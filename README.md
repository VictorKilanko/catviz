# catviz: Causal Assignment Tree Visualization for Staggered DiD, DDD, and Related Designs

**catviz** is an R package for visualizing and understanding **Causal Assignment Trees (CATs)** — hierarchical structures that summarize treatment timing, subgroup composition, and sample classification in **staggered difference-in-differences (CSDID) and staggered DDD like DRDDD** and related causal inference frameworks.

It provides a publication-ready visualization of treated, control, and never-treated groups, along with counts and subgroup summaries, to help researchers verify sample balance and treatment assignment logic.

---

## Working Example

The example creates simulated panel data for **hospitals nested within states**,  
where **states adopt treatment at different years**, and hospitals may also belong  
to binary subgroups (for DR-DDD analysis).

---

## Variable definitions

| Variable | Role | Description |
|-----------|------|-------------|
| `hospital_id` | **Unit ID** | Unique identifier for each hospital (unit of analysis). |
| `state` | **Group ID** | State identifier — treatment is assigned at this level. All hospitals in a state share the same treatment adoption year `g`. |
| `year` | **Time** | Calendar year (panel time dimension). |
| `g` | **First Treatment Year** | The first year the state adopts treatment (or `Inf` if never treated). |
| `p` | **Subgroup** | Binary subgroup indicator (e.g., `p = 0` vs. `p = 1`), used only for **DR-DDD**. Omit this variable for **CSDID**. |

---

## Example code

```r
# =======================================================
# Example: State-level staggered adoption with subgroups
# =======================================================

# Install if needed
# install.packages("devtools")
# devtools::install_github("VictorKilanko/catviz")

library(catviz)
library(dplyr)
library(tidyr)
library(purrr)  # for map()

set.seed(123)

# ---------------------------
# 1. Define simulation setup
# ---------------------------
states <- sprintf("S%02d", 1:20)    # 20 states
years  <- 2014:2023
N_hosp <- 5                         # 5 hospitals per state

# Each state adopts treatment in a different year (staggered)
adopt_years <- c(2015, 2016, 2019, 2020, 2021, 2023, Inf)

state_level <- tibble(
  state = states,
  g = sample(adopt_years, length(states), replace = TRUE)
)

# ---------------------------
# 2. Create hospitals within states
# ---------------------------
hospitals <- state_level %>%
  mutate(
    hospital_id = map(state, ~ paste0(.x, "_H", 1:N_hosp))
  ) %>%
  unnest(hospital_id) %>%
  mutate(
    p = sample(0:1, n(), replace = TRUE)  # subgroup (omit for CSDID)
  )

# ---------------------------
# 3. Expand to panel structure
# ---------------------------
example_data <- expand_grid(
  hospital_id = hospitals$hospital_id,
  year = years
) %>%
  left_join(hospitals, by = "hospital_id") %>%
  arrange(hospital_id, year)

# ---------------------------
# 4. Define CAT specification
# ---------------------------
spec <- cat_spec(
  data      = example_data,
  id        = "hospital_id",  # unit of analysis
  time      = "year",         # calendar year
  g         = "g",            # first treatment year (state-level)
  subgroup  = "p",            # only for DR-DDD; omit for pure CSDID
  group_id  = "state"         # treatment assigned at state level
)

# Label nodes for clarity
spec <- cat_label(spec)

# ---------------------------
# 5. Summaries and visualization
# ---------------------------
cat_counts(spec)

dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

out <- cat_plot_tree(
  spec,
  save_plot  = "man/figures/CAT_plot_example.png",
  save_table = "man/figures/CAT_summary_example.csv"
)

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

