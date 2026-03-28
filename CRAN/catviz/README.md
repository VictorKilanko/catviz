# catviz: Causal Assignment Tree Visualization for Staggered DiD and DR-DDD Designs

**catviz** is an R package for visualizing **Causal Assignment Trees (CATs)** — hierarchical diagrams that show treatment timing, never-treated vs. not-yet-treated composition, and subgroup structure in staggered difference-in-differences (CSDiD) and doubly robust DDD (DR-DDD) designs.

---

## Installation

```r
# Install from GitHub (while awaiting CRAN approval)
install.packages("devtools")  # if not already installed
devtools::install_github("VictorKilanko/catviz", subdir = "catviz")
```

---

## Key functions

| Function | What it does |
|---|---|
| `cat_spec()` | Entry point — builds the CAT specification from your panel data |
| `cat_plot_tree()` | Plots the CAT (auto-detects design: CSDiD or DR-DDD) |
| `cat_counts()` | Returns node-level unit counts |
| `cat_pt_csdid()` | Pre-trends diagnostic for CSDiD |
| `cat_pt_drddd()` | Pre-trends diagnostic for DR-DDD |
| `cat_balance_plot()` | Covariate balance plot across nodes |

---

## Quick start: CSDiD (staggered adoption, no subgroup)

```r
library(catviz)

# Panel data: one row per unit x time period
# g = first treatment year; Inf = never treated
df <- data.frame(
  id   = rep(1:9, each = 5),
  year = rep(2016:2020, 9),
  g    = c(rep(2017, 15),   # cohort A
           rep(2018, 15),   # cohort B
           rep(Inf, 15))    # never-treated
)

spec <- cat_spec(df, id = "id", time = "year", g = "g")

cat_counts(spec)       # unit counts per node
cat_plot_tree(spec)    # plots the CAT (auto-detects CSDiD)
```

---

## Quick start: DR-DDD (staggered adoption + binary subgroup)

```r
library(catviz)

df <- data.frame(
  id   = rep(1:9, each = 5),
  year = rep(2016:2020, 9),
  g    = c(rep(2017, 15), rep(2018, 15), rep(Inf, 15)),
  p    = rep(c(0L, 1L), length.out = 45)   # binary subgroup
)

spec <- cat_spec(df, id = "id", time = "year", g = "g", subgroup = "p")

cat_counts(spec)
cat_plot_tree(spec)
```

---

## Larger example: state-level staggered adoption with hospitals

```r
library(catviz)
library(dplyr)
library(tidyr)
library(purrr)

set.seed(123)

states <- sprintf("S%02d", 1:20)
years  <- 2014:2023

adopt_years <- c(2015, 2016, 2019, 2020, 2021, 2023, Inf)

state_level <- tibble(
  state = states,
  g     = sample(adopt_years, length(states), replace = TRUE)
)

hospitals <- state_level %>%
  mutate(hospital_id = map(state, ~ paste0(.x, "_H", 1:5))) %>%
  unnest(hospital_id) %>%
  mutate(p = sample(0:1, n(), replace = TRUE))  # omit for pure CSDiD

example_data <- expand_grid(hospital_id = hospitals$hospital_id, year = years) %>%
  left_join(hospitals, by = "hospital_id") %>%
  arrange(hospital_id, year)

# DR-DDD spec (include subgroup = "p")
spec <- cat_spec(
  data     = example_data,
  id       = "hospital_id",
  time     = "year",
  g        = "g",
  subgroup = "p",       # omit this line for pure CSDiD
  group_id = "state"    # treatment assigned at state level
)

cat_counts(spec)
cat_plot_tree(spec)

# Grayscale version (for publication)
cat_plot_tree(spec, grayscale = TRUE)

# Save the plot
cat_plot_tree(spec, save_plot = "my_cat_plot.png")
```

---

## `cat_spec()` argument reference

| Argument | Required | Description |
|---|---|---|
| `data` | Yes | Panel data frame (one row per unit x time) |
| `id` | Yes | Unit identifier column name |
| `time` | Yes | Time column name |
| `g` | Yes | First treatment year column (`Inf` or `0` = never treated) |
| `subgroup` | No | Binary (0/1) subgroup column — include for DR-DDD, omit for CSDiD |
| `group_id` | No | Higher-level group if treatment assigned above unit level (e.g. state) |
| `never_treated_values` | No | Values of `g` that mean never-treated (default: `c(0, Inf)`) |

---

## Common errors

**`argument "subgroup" is missing`** — you have an old version installed. Reinstall:
```r
devtools::install_github("VictorKilanko/catviz", subdir = "catviz")
```

**`could not find function "cat_plot_tree"`** — restart R and reload:
```r
library(catviz)
```

---

## Citation

Kilanko, V. (2026). *catviz: Causal Assignment Tree Visualization for Staggered DiD and DR-DDD Designs*. https://github.com/VictorKilanko/catviz

Methods based on:
- Callaway & Sant'Anna (2021). doi:10.1016/j.jeconom.2020.12.001
- Sant'Anna & Zhao (2020). doi:10.1016/j.jeconom.2020.06.003
