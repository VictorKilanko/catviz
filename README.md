# catviz: Causal Assignment Tree Visualization for DiD, CSDID, and DDD

**catviz** is an R package for visualizing and diagnosing **Causal Assignment Trees (CATs)** — hierarchical diagrams that show how units are assigned to treatment, comparison, and subgroup branches in causal inference designs such as:

- **Difference-in-Differences (DiD)**
- **CSDID** (Callaway & Sant’Anna)
- **DDD** (Difference-in-Difference-in-Differences)

The package supports **staggered** and **non-staggered** adoption and helps researchers:

- verify treatment timing (`g`)
- confirm cohort definitions
- examine pre/post splitting (`t < g` vs. `t ≥ g`)
- inspect subgroup splits (DDD)
- produce clean, publication-ready diagrams
- generate cohort summary tables

---

## ⭐ Key Features

- Unified visualization for **DiD**, **CSDID**, and **DDD**
- Supports **any number of treated cohorts** (`g = 2…10`) + **never-treated**
- Optional binary subgroup splitting (`Q = 0/1`)
- Counts by **units** or **observations**
- Optional **count-free** “schematic” diagrams for publications
- Automatically saves:
  - CAT plot (`.png`)
  - Summary table (`.csv`)
- Works out of the box with minimal code

---

## 📦 Installation

```r
install.packages("devtools")
devtools::install_github("VictorKilanko/catviz")


### When to Use `catviz`

Use `catviz` whenever you want to **understand or verify your causal design structure** before estimating DiD, CSDID, or DDD models — for instance:

- Check that treated and never-treated units are correctly defined  
- Verify treatment timing (`t < g` vs. `t ≥ g`)  
- Confirm that treatment cohorts (`g`) are properly recorded  
- Ensure subgroup splits (`Q`) exist and are correctly coded (DDD only)  
- Produce clean, publication-ready diagrams of your identification design  
- Document your treatment structure transparently for replication  

---

## Working Example

The following example simulates panel data for **hospitals nested inside states**,  
where:

- States adopt treatment at different years (`g`)
- Hospitals inherit the treatment timing of their state
- Hospitals may also belong to binary subgroups (`Q`) for DDD analysis

The same dataset can be used to create **DiD**, **CSDID**, and **DDD** trees depending on whether you include `subgroup`.

---

## Variable definitions

| Variable | Role | Description |
|-----------|------|-------------|
| `hospital_id` | **Unit ID** | Unique identifier for each hospital. |
| `state` | **Group ID** | Treatment occurs at the state level; all hospitals in a state share the same first treatment year `g`. |
| `year` | **Time** | Calendar year (panel time). |
| `g` | **First Treatment Year** | Earliest year the state adopts treatment, or `Inf` if never treated. |
| `Q` | **Subgroup** | Binary subgroup (0/1), required **only for DDD**. |

---

## Example Code

```r
# =======================================================
# Example: State-level staggered adoption with subgroups
# =======================================================

# install.packages("devtools")
# devtools::install_github("VictorKilanko/catviz")

library(catviz)
library(dplyr)
library(tidyr)
library(purrr)

set.seed(123)

# =======================================================
# 1. State structure
# =======================================================
states <- sprintf("S%02d", 1:20)
years  <- 2014:2023
N_hosp <- 5

treat_years <- c(2015, 2016, 2019, 2020, 2021, 2023, Inf)

state_info <- tibble(
  state = states,
  g     = sample(treat_years, length(states), replace = TRUE)
)

# =======================================================
# 2. Hospitals nested in states
# =======================================================
hospitals <- state_info %>%
  mutate(hospital_id = map(state, ~ paste0(.x, "_H", 1:N_hosp))) %>%
  unnest(hospital_id) %>%
  mutate(Q = rbinom(n(), 1, 0.5))   # subgroup for DDD (omit for DID)

# =======================================================
# 3. Expand to panel
# =======================================================
panel <- expand_grid(
  hospital_id = hospitals$hospital_id,
  year        = years
) %>%
  left_join(hospitals, by = "hospital_id") %>%
  arrange(hospital_id, year)

# =======================================================
# 4. Build CAT specification
# =======================================================
spec <- cat_spec(
  data     = panel,
  id       = "hospital_id",
  time     = "year",
  g        = "g",
  subgroup = "Q",       # remove this line for DID or CSDID
  group_id = "state"
)

spec <- cat_label(spec)

# =======================================================
# 5. Counts summary
# =======================================================
cat_counts(spec)

# =======================================================
# 6. Visualizations
# =======================================================
dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

# DID diagram (ignore subgroup)
p_did <- cat_plot_did(spec)
ggplot2::ggsave("man/figures/did.png", p_did, width = 10, height = 7)

# CSDID diagram (cohorts only)
p_csdid <- cat_plot_csdid(spec)
ggplot2::ggsave("man/figures/csdid.png", p_csdid, width = 10, height = 7)

# DDD diagram (cohorts × Q)
p_ddd <- cat_plot_ddd(spec)
ggplot2::ggsave("man/figures/ddd.png", p_ddd, width = 10, height = 7)

# =======================================================
# 7. Display example
# =======================================================
print(p_ddd)

