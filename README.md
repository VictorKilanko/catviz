# catviz: Visualizing Causal Assignment Trees for DiD, CSDiD, and DDD

[![R](https://img.shields.io/badge/R-%3E%3D4.1.0-blue)](https://www.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN status](https://img.shields.io/badge/CRAN-submission%20pending-lightgrey)](https://CRAN.R-project.org/package=catviz)

**catviz** is an R package for constructing, labeling, and visualizing **Causal Assignment Trees (CATs)** — hierarchical diagrams that make the identification strategy in modern difference-in-differences designs explicit and transparent. The package supports three design classes:

- **2×2 Difference-in-Differences (DiD)** — one treated group, one control group, one treatment time
- **Callaway–Sant'Anna CSDiD** — staggered adoption across multiple treatment cohorts
- **Doubly Robust Triple Difference (DR-DDD)** — staggered adoption with subgroup heterogeneity

CAT diagrams communicate who serves as the counterfactual, how cohort composition varies, and how the ATT is constructed — all before a single regression is run.

---

## Why Use catviz?

Credible causal inference requires knowing which units provide identification and why. The standard practice of reporting a regression table without visualizing treatment structure makes it difficult to evaluate internal validity, detect composition problems, or explain the design to non-technical audiences.

The CAT solves this. It displays the full assignment structure — cohorts, never-treated units, subgroups, pre/post splits, and sample sizes — in a single diagram that maps directly to the econometric identifying assumptions.

**Key benefits:**

- **Transparency** — shows exactly which units serve as comparison groups
- **Verification** — exposes structural problems (empty cells, thin cohorts) before estimation
- **Diagnostics** — built-in pretrend and covariate balance tools
- **Communication** — suitable for papers, seminars, and referee responses
- **Publication quality** — high-resolution output with a grayscale option for B&W journals

---

## Installation

catviz is currently available from GitHub while awaiting CRAN approval:

```r
# Install from GitHub (recommended while CRAN approval is pending)
# install.packages("remotes")  # if not already installed
remotes::install_github("VictorKilanko/catviz", subdir = "CRAN/catviz")

# or with devtools:
# devtools::install_github("VictorKilanko/catviz", subdir = "CRAN/catviz")
```

Once approved, it will also be installable via:

```r
install.packages("catviz")
```

---

## Quick Start

The recommended entry point is `cat_plot_tree()`, which automatically detects your design and dispatches to the correct plot function.

```r
library(catviz)

# --- Step 1: Specify the CAT ---
spec <- cat_spec(
  data = your_panel,
  id   = "unit_id",
  time = "year",
  g    = "first_treatment_year"   # use Inf for never-treated units
)

# --- Step 2: (Optional) Attach cohort labels ---
spec <- cat_label(spec)

# --- Step 3: Inspect node counts ---
cat_counts(spec)

# --- Step 4: Visualize (auto-detects design) ---
p <- cat_plot_tree(spec, counts = TRUE)
print(p)

# --- Step 5: Save ---
cat_save_png(p, "figure1_cat.png")
```

`cat_plot_tree()` prints a message indicating the detected design (`CAT design detected: CSDiD`, `DDD`, or `2x2 DiD`) so you can verify the dispatch is correct.

---

## Three Designs, One Framework

### 1. Standard 2×2 DiD

Use when there is one treatment time and one control group.

```r
spec_did <- cat_spec(
  data = panel_data,
  id   = "city_id",
  time = "year",
  g    = "treatment_year"
)

p <- cat_plot_tree(spec_did)   # dispatches to cat_plot_did()
```

**Tree structure:**
```
All Units
  ├─ Treated
  │    ├─ Pre-period
  │    └─ Post-period
  └─ Control (Never-Treated)
       ├─ Pre-period
       └─ Post-period
```

---

### 2. CSDiD — Staggered Adoption (Callaway–Sant'Anna)

Use when different units adopt treatment at different times.

```r
spec_csdid <- cat_spec(
  data = panel_data,
  id   = "city_id",
  time = "year",
  g    = "adoption_year"        # Inf for never-treated
)

p <- cat_plot_tree(spec_csdid)  # dispatches to cat_plot_csdid()
```

**Tree structure:**
```
All Units
  ├─ Cohort g = 2019  [A]
  ├─ Cohort g = 2020  [B]
  ├─ Cohort g = 2021  [C]
  └─ Never-Treated    [D]
```

---

### 3. DR-DDD — Triple Difference with Subgroups

Use when treatment effects differ across a binary subgroup within cohorts (e.g., hospital type, firm size, gender).

```r
spec_ddd <- cat_spec(
  data     = panel_data,
  id       = "hospital_id",
  time     = "year",
  g        = "expansion_year",
  subgroup = "nonprofit"        # binary 0/1
)

p <- cat_plot_tree(spec_ddd)    # dispatches to cat_plot_ddd()
```

**Tree structure:**
```
All Units
  ├─ Cohort g = 2014
  │    ├─ Subgroup Q = 1  [A]
  │    └─ Subgroup Q = 0  [B]
  ├─ Cohort g = 2015
  │    ├─ Q = 1  [C]
  │    └─ Q = 0  [D]
  └─ Never-Treated
       ├─ Q = 1  [M]
       └─ Q = 0  [N]
```

---

## Real-World Examples

### Example 1: Psychedelics Deprioritization and Crime (CSDiD)

Five California cities adopted psychedelics deprioritization policies between 2019 and 2023, against a background of 284 never-adopting cities.

```r
library(catviz)

df <- data.frame(
  city_id        = rep(1:6, each = 4),
  year           = rep(2019:2022, 6),
  treatment_year = c(rep(2020, 8), rep(2021, 8), rep(Inf, 8))
)

spec <- cat_spec(df, id = "city_id", time = "year", g = "treatment_year")
p    <- cat_plot_tree(spec, counts = TRUE)
```

The CAT immediately reveals that the earliest cohort (Oakland, 2019) can use all subsequent adopters and all never-treated cities as comparisons, while the latest cohort (Berkeley, 2023) relies entirely on the never-treated pool.

---

### Example 2: Medicaid Expansion and Hospital Outcomes (DR-DDD)

Medicaid expansion rolled out across US states in 8 distinct cohorts. The DDD design estimates heterogeneous effects for non-profit (Q=1) vs. for-profit (Q=0) hospitals.

```r
library(catviz)
library(dplyr)

# Simulated data with subgroup structure
set.seed(42)
df <- expand.grid(
  hospital_id    = 1:200,
  year           = 2012:2022
) |>
  mutate(
    expansion_year = rep(sample(c(2014, 2015, 2016, 2019, Inf), 200, replace = TRUE), each = 11),
    nonprofit      = rep(rbinom(200, 1, 0.6), each = 11)
  )

spec_ddd <- cat_spec(df,
  id       = "hospital_id",
  time     = "year",
  g        = "expansion_year",
  subgroup = "nonprofit"
)

p <- cat_plot_tree(spec_ddd, counts = TRUE)
```

---

## Understanding the Output

### Node colors

| Color | Meaning |
|-------|---------|
| Dark fill | Treated units (post-treatment) |
| Light fill | Control / never-treated units |
| White | Internal branch nodes |

Set `grayscale = TRUE` in `cat_plot_tree()` for black-and-white output suitable for print journals.

### Node labels

Each terminal node displays:
- **Group identifier** — cohort year or subgroup value
- **Letter label** — assigned chronologically (A, B, C, ...) for cross-reference with equations
- **Sample size** — when `counts = TRUE`

### Letter assignment convention

- **CSDiD**: A = earliest cohort, ..., last letter = never-treated group
- **DDD**: A, B = first cohort Q=1 and Q=0; C, D = second cohort; etc.

---

## Diagnostics

### Pretrend and parallel-trends tests

```r
# Event-time count table (no outcome required)
cat_diag(spec, method = "event")

# CSDiD parallel-trends diagnostic: gap(treated - never-treated) over pre-periods
cat_diag(spec, outcome = "y", method = "csdid")

# DR-DDD pretrend: subgroup means (Q=1 vs Q=0) over pre-periods
cat_diag(spec_ddd, outcome = "y", method = "drddd")
```

All methods return a list with a `data` tibble and (for `"csdid"` and `"drddd"`) a `plot` element that is printed automatically.

### Covariate balance

```r
# Standardized mean differences by design group (Treated vs. Never-Treated)
bal <- cat_balance_table(spec, covariates = c("age", "income", "population"),
                         by = "design")

# Love plot
cat_balance_plot(bal)

# By CAT node (finer decomposition)
bal_node <- cat_balance_table(spec, covariates = c("age", "income"),
                              by = "node")
```

### ATT formula reference

```r
# Returns ATT formula in plain text and LaTeX for the paper
cat_att_equation(design = "drddd")
cat_att_equation(design = "csdid", subgroup_value = 1)
```

Each call returns a list with `text`, `tex`, `nodes`, and `note`, so the formula can be inserted directly into `knitr` or a LaTeX document.

---

## Function Reference

### Specification

| Function | Description |
|----------|-------------|
| `cat_spec(data, id, time, g, subgroup, group_id)` | Build a `cat_spec` object from panel data |
| `cat_label(spec)` | Attach letter labels and canonical node descriptors |

### Visualization

| Function | Description |
|----------|-------------|
| `cat_plot_tree(spec, counts, grayscale, save_plot, ...)` | **Recommended.** Auto-detects design; dispatches to the function below |
| `cat_plot_did(spec, counts, save_plot, ...)` | 2×2 DiD tree |
| `cat_plot_csdid(spec, counts, save_plot, ...)` | CSDiD tree (staggered adoption) |
| `cat_plot_ddd(spec, counts, save_plot, ...)` | DR-DDD tree with subgroup split |
| `cat_save_png(plot, path, width, height, dpi)` | Save a CAT plot to high-resolution PNG |

### Summary statistics

| Function | Description |
|----------|-------------|
| `cat_counts(spec)` | Count units or observations per CAT node |

### Diagnostics

| Function | Description |
|----------|-------------|
| `cat_diag(spec, outcome, method, ...)` | Unified diagnostic dispatcher (`"event"`, `"drddd"`, `"csdid"`) |
| `cat_balance_table(spec, covariates, by, weight)` | Standardized mean differences across nodes or design groups |
| `cat_balance_plot(balance_tbl)` | Love plot from a `cat_balance_table()` result |
| `cat_att_equation(design, subgroup_value, include_never_treated)` | ATT formula in text and LaTeX |

---

## Integration with DiD Estimation Packages

`catviz` is designed as a pre-estimation workflow tool. It pairs naturally with:

### `did` (Callaway & Sant'Anna)

```r
library(catviz)
library(did)

# 1. Inspect treatment structure
spec <- cat_spec(data, id = "id", time = "year", g = "g")
cat_plot_tree(spec)

# 2. Estimate cohort-average ATTs
out <- att_gt(yname = "y", tname = "year", idname = "id", gname = "g", data = data)
aggte(out, type = "dynamic")
```

### `fixest` (Sun–Abraham)

```r
library(catviz)
library(fixest)

spec <- cat_spec(data, id = "id", time = "year", g = "g")
cat_plot_tree(spec)

feols(y ~ sunab(g, year) | id + year, data = data)
```

### `drdid` (Sant'Anna & Zhao doubly robust DiD)

```r
library(catviz)
library(drdid)

spec <- cat_spec(data, id = "id", time = "year", g = "g")
cat_plot_tree(spec)
```

---

## Advanced Usage

### Grayscale output for print journals

```r
p <- cat_plot_tree(spec, counts = TRUE, grayscale = TRUE)
cat_save_png(p, "figure1_bw.png")
```

### Calling underlying plot functions directly

```r
# With additional ggplot2 customization
p <- cat_plot_csdid(spec, counts = TRUE) +
  ggplot2::labs(title = "Treatment Assignment Structure") +
  ggplot2::theme(plot.title = ggplot2::element_text(size = 14, face = "bold"))
```

### Accessing diagnostic data

```r
result <- cat_diag(spec, outcome = "y", method = "csdid", pre_window = -6:-1)
head(result$data)   # the underlying tibble
```

---

## Variable Requirements

### Required

| Argument | Type | Description |
|----------|------|-------------|
| `id` | Character or numeric | Unique unit identifier (panel dimension) |
| `time` | Numeric or Date | Time period |
| `g` | Numeric or Date | First treatment period; use `Inf` or `0` for never-treated |

### Optional

| Argument | Type | When needed |
|----------|------|-------------|
| `subgroup` | Binary integer (0/1) | DR-DDD designs only |
| `group_id` | Character or numeric | When treatment is assigned at a higher level (e.g., state) |

---

## Tips

1. **Run `cat_plot_tree()` before any estimation.** The diagram will surface structural problems — empty cohorts, small control pools, incorrect `Inf` coding — that would otherwise silently bias your estimates.

2. **Use `cat_counts()` to audit sample sizes.** Cohorts with very few observations should be collapsed or excluded before computing ATT(g,t) estimates.

3. **Save at high resolution.** The default DPI for `cat_save_png()` is 400. For journal submission, verify the minimum DPI requirement (typically 300–600).

4. **Cite the CAT in your paper.** A natural caption is:
   > "Figure 1 presents the Causal Assignment Tree for our staggered DiD design. Letters A–D denote treatment cohorts in chronological order; letter E denotes the never-treated comparison group."

---

## Troubleshooting

**"No treated cohorts detected"**
Check that the `g` column contains finite values for treated units and `Inf` (or `0`) for never-treated units. Do not leave `NA`.

**Tree labels are cut off**
The ggplot2 viewport clips labels at the panel boundary. Call `cat_save_png()` or `ggsave()` with a larger `width` argument.

**"spec must be a cat_spec object"**
Pass the output of `cat_spec()` directly. Do not pass a raw data frame.

**Plot is too narrow for many cohorts**
The DDD plot auto-scales width, but for large designs (10+ cohorts) you may need to increase it manually:
```r
cat_save_png(p, "wide_cat.png", width = 28, height = 12)
```

---

## Citation

If you use catviz in published research, please cite:

```bibtex
@misc{kilanko2025catviz,
  author    = {Kilanko, Victor},
  title     = {catviz: Visualizing Causal Assignment Trees for DiD, CSDiD, and DDD},
  year      = {2025},
  publisher = {GitHub},
  url       = {https://github.com/VictorKilanko/catviz}
}
```

---

## References

- Callaway, B., & Sant'Anna, P. H. C. (2021). Difference-in-differences with multiple time periods. *Journal of Econometrics*, 225(2), 200–230.
- Goodman-Bacon, A. (2021). Difference-in-differences with variation in treatment timing. *Journal of Econometrics*, 225(2), 254–277.
- Ortiz-Villavicencio, L., & Sant'Anna, P. H. C. (2025). Difference-in-difference-in-differences. Working paper.
- Sant'Anna, P. H. C., & Zhao, J. (2020). Doubly robust difference-in-differences estimators. *Journal of Econometrics*, 219(1), 101–122.
- Kilanko, V. (2025). Visualizing counterfactuals: A causal assignment tree approach for DiD, CSDiD, and DDD. Working paper.

---

## Contributing

Bug reports and feature requests are welcome via [GitHub Issues](https://github.com/VictorKilanko/catviz/issues). Pull requests should include a minimal reproducible example and updated documentation.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Contact

Victor Kilanko — victorkilanko@gmail.com
Issues: [github.com/VictorKilanko/catviz/issues](https://github.com/VictorKilanko/catviz/issues)
