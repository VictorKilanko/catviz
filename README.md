# catviz: Visualizing Causal Assignment Trees for DiD, CSDiD, and DDD

[![R](https://img.shields.io/badge/R-%3E%3D4.0.0-blue)](https://www.r-project.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**catviz** is a professional R package for creating publication-quality **Causal Assignment Tree (CAT)** visualizations. These hierarchical diagrams transparently display the treatment structure in modern difference-in-differences designs, including:

- **2×2 Difference-in-Differences (DiD)**
- **Callaway-Sant'Anna DiD (CSDiD)** with staggered adoption
- **Difference-in-Difference-in-Differences (DDD)** with subgroup heterogeneity

The CAT framework makes your identification strategy visually transparent, showing exactly which units serve as controls, how treatment timing varies across cohorts, and how counterfactual outcomes are constructed.

---

## Why Use catviz?

In causal inference, **knowing who serves as the counterfactual is essential** for understanding what is being estimated. The CAT provides this insight at a glance.

### Key Benefits

 **Transparency** – See exactly which units serve as comparison groups  
 **Verification** – Confirm treatment structure before estimation  
 **Communication** – Explain complex designs to non-technical audiences  
 **Publication-Ready** – Professional diagrams for papers and presentations  
 **Flexible** – Works with any number of cohorts and subgroups  

---

## Installation

```r
# Install from GitHub
install.packages("devtools")
devtools::install_github("VictorKilanko/catviz")
```

---

## Quick Start

### Basic Workflow

```r
library(catviz)

# 1. Create CAT specification from your data
spec <- cat_spec(
  data     = your_data,
  id       = "unit_id",
  time     = "year",
  g        = "treatment_year",
  group_id = "state"
)

# 2. Add labels
spec <- cat_label(spec)

# 3. View summary statistics
cat_counts(spec)

# 4. Create visualization
p <- cat_plot_csdid(spec, counts = TRUE, save_plot = "my_cat.png")
print(p)
```

---

## Three Designs, One Framework

### 1. Standard 2×2 DiD

**Use when:** You have one treatment time and one control group.

```r
# Example: Single policy adoption
spec_did <- cat_spec(
  data = panel_data,
  id   = "city_id",
  time = "year",
  g    = "treatment_year"
)

p_did <- cat_plot_did(spec_did, counts = TRUE)
```

**CAT Structure:**
```
All Units
  ├─ Treated (A)
  │    ├─ Pre (C)
  │    └─ Post (D)
  └─ Control (B)
       ├─ Pre (E)
       └─ Post (F)
```

---

### 2. CSDiD (Staggered Adoption)

**Use when:** Different units adopt treatment at different times.

```r
# Example: Staggered policy rollout across cities
spec_csdid <- cat_spec(
  data     = panel_data,
  id       = "city_id",
  time     = "month",
  g        = "adoption_date",
  group_id = "city_id"
)

p_csdid <- cat_plot_csdid(spec_csdid, counts = TRUE)
```

**CAT Structure:**
```
All Units
  ├─ Treated Cohorts
  │    ├─ g = 2019 (A)
  │    ├─ g = 2020 (B)
  │    ├─ g = 2021 (C)
  │    └─ ...
  └─ Never-Treated (g=∞) (F)
```

**Real-World Example:** Psychedelics deprioritization policies adopted by California cities at different times.

---

### 3. DDD (Triple Difference with Subgroups)

**Use when:** Treatment effects may differ across subgroups within cohorts.

```r
# Example: Policy affects non-profit differently than for-profit hospitals
spec_ddd <- cat_spec(
  data     = panel_data,
  id       = "hospital_id",
  time     = "year",
  g        = "expansion_year",
  subgroup = "nonprofit",      # Key addition for DDD
  group_id = "state"
)

p_ddd <- cat_plot_ddd(spec_ddd, counts = TRUE)
```

**CAT Structure:**
```
All Units
  ├─ Treated Cohorts
  │    ├─ g = 2014
  │    │    ├─ Q = 1 (A)
  │    │    └─ Q = 0 (B)
  │    ├─ g = 2015
  │    │    ├─ Q = 1 (C)
  │    │    └─ Q = 0 (D)
  │    └─ ...
  └─ Never-Treated (g=∞)
       ├─ Q = 1 (M)
       └─ Q = 0 (N)
```

**Real-World Example:** Medicaid expansion affecting non-profit vs. for-profit hospitals.

---

## Featured Examples

### Example 1: Psychedelics Deprioritization and Crime (CSDiD)

A motivating example analyzing the effect of psychedelics deprioritization policies on crime rates in California cities.

**Context:**
- 5 cities adopted deprioritization between 2019-2023
- 284 cities never adopted (control group)
- Monthly panel data (2017-2023)

```r
library(catviz)
library(dplyr)

# Load data (simplified for illustration)
psychedelics_data <- data.frame(
  city_id = rep(1:289, each = 72),
  month   = rep(seq(as.Date("2017-01-01"), by = "month", length.out = 72), 289),
  treatment_date = rep(c(
    rep(as.Date("2019-06-01"), 1),    # Oakland
    rep(as.Date("2020-01-01"), 1),    # Santa Cruz
    rep(as.Date("2021-10-01"), 1),    # Arcata
    rep(as.Date("2022-09-01"), 1),    # San Francisco
    rep(as.Date("2023-07-01"), 1),    # Berkeley
    rep(Inf, 284)                     # Never-treated
  ), each = 72)
)

# Create CAT specification
spec <- cat_spec(
  data     = psychedelics_data,
  id       = "city_id",
  time     = "month",
  g        = "treatment_date",
  group_id = "city_id"
)

spec <- cat_label(spec)

# Generate CAT visualization
p <- cat_plot_csdid(spec, counts = TRUE, save_plot = "psychedelics_cat.png")
print(p)
```

**Key Insight:** The CAT shows that Oakland (earliest adopter) can use all other cities as comparisons, while Berkeley (latest adopter) can only use the 284 never-treated cities.

---

### Example 2: Medicaid Expansion and Hospital Outcomes (DDD)

A DDD analysis examining differential effects of Medicaid expansion on non-profit vs. for-profit hospitals.

**Context:**
- 8 expansion cohorts (2014-2025)
- 3,495 hospitals across 50 states
- Subgroups: Non-profit (Q=1) vs. For-profit (Q=0)

```r
library(catviz)
library(dplyr)
library(tidyr)

# Simulate Medicaid expansion structure
set.seed(123)

# State expansion years
states <- data.frame(
  state = state.abb,
  expansion_year = sample(c(2014, 2015, 2016, 2019, 2020, 2021, 2023, 2025, Inf), 
                         50, replace = TRUE)
)

# Hospitals in each state
hospitals <- states %>%
  slice(rep(1:n(), each = 70)) %>%
  mutate(
    hospital_id = paste0(state, "_H", 1:70),
    nonprofit = rbinom(n(), 1, 0.6)  # 60% non-profit
  )

# Panel data (2012-2025)
panel <- expand_grid(
  hospital_id = hospitals$hospital_id,
  year = 2012:2025
) %>%
  left_join(hospitals, by = "hospital_id")

# Create DDD specification
spec_ddd <- cat_spec(
  data     = panel,
  id       = "hospital_id",
  time     = "year",
  g        = "expansion_year",
  subgroup = "nonprofit",
  group_id = "state"
)

spec_ddd <- cat_label(spec_ddd)

# Generate DDD tree
p_ddd <- cat_plot_ddd(spec_ddd, counts = TRUE, save_plot = "medicaid_ddd_cat.png")
print(p_ddd)

# View summary statistics
cat_counts(spec_ddd)
```

**Key Insight:** The CAT reveals that the 2014 cohort has 7 valid comparison cohorts (2015, 2016, 2019, 2020, 2021, 2023, 2025) plus the never-treated group, allowing for over-identified GMM estimation.

---

## Understanding CAT Output

### Node Labels

Each node in the CAT is labeled with:
- **Group identifier** (e.g., "g = 2019", "Q = 1")
- **Letter label** (A, B, C, ...) for easy reference in equations
- **Sample size** (n=X) when `counts = TRUE`

### Colors

- **Pink/Red** (#FADBD8): Treated units
- **Blue** (#D6EAF8): Control/Never-treated units
- **White**: Internal nodes (branches)

### Letter Assignment

Letters are assigned **chronologically**:
- **CSDiD**: A = earliest cohort, ..., last letter = never-treated
- **DDD**: A,B = first cohort (Q=1, Q=0), C,D = second cohort, etc.

---

## Variable Requirements

### Required Variables

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `id` | Character/Numeric | Unique unit identifier | `"hospital_001"`, `12345` |
| `time` | Date/Numeric | Time period | `2020`, `as.Date("2020-01-01")` |
| `g` | Date/Numeric | First treatment time (use `Inf` for never-treated) | `2019`, `Inf` |

### Optional Variables

| Variable | Type | Description | When Required |
|----------|------|-------------|---------------|
| `subgroup` | Binary (0/1) | Subgroup indicator | **DDD only** |
| `group_id` | Character/Numeric | Treatment assignment level | When treatment is clustered (e.g., states) |

---

## Function Reference

### Core Functions

#### `cat_spec()`
Creates a CAT specification object from panel data.

```r
spec <- cat_spec(
  data,           # Panel dataset (data.frame)
  id,             # Unit identifier column name
  time,           # Time variable column name
  g,              # First treatment time column name
  subgroup = NULL,# Subgroup column (DDD only)
  group_id = NULL # Treatment assignment level
)
```

#### `cat_label()`
Adds letter labels to cohorts and subgroups.

```r
spec <- cat_label(spec)
```

#### `cat_counts()`
Displays summary statistics by cohort and subgroup.

```r
cat_counts(spec)
```

### Visualization Functions

#### `cat_plot_did()`
Creates 2×2 DiD tree with Pre/Post splits.

```r
p <- cat_plot_did(
  spec,
  counts = TRUE,        # Include sample sizes
  save_plot = NULL      # Optional: path to save PNG
)
```

#### `cat_plot_csdid()`
Creates CSDiD tree with multiple treatment cohorts.

```r
p <- cat_plot_csdid(
  spec,
  counts = TRUE,
  save_plot = NULL
)
```

#### `cat_plot_ddd()`
Creates DDD tree with cohorts and subgroups.

```r
p <- cat_plot_ddd(
  spec,
  counts = TRUE,
  save_plot = NULL
)
```

---

## Advanced Usage

### Customizing Plots

All plotting functions return `ggplot2` objects, which can be customized:

```r
library(ggplot2)

p <- cat_plot_csdid(spec, counts = TRUE)

# Customize
p_custom <- p +
  labs(title = "My Custom Title") +
  theme(plot.title = element_text(size = 20, face = "bold"))

# Save with custom dimensions
ggsave("my_cat_custom.png", p_custom, width = 16, height = 10, dpi = 400)
```

### Hiding Sample Sizes

For theoretical/schematic diagrams:

```r
p_clean <- cat_plot_csdid(spec, counts = FALSE)
```

### Working with Large Datasets

For datasets with many cohorts (>10), the DDD plot automatically adjusts width:

```r
# Width scales from 14" to 30+" based on number of cohorts
p_wide <- cat_plot_ddd(spec, save_plot = "wide_cat.png")
# Automatically saves with appropriate width
```

---

## Integration with DiD Packages

`catviz` complements existing DiD estimation packages:

### With `did` package (Callaway & Sant'Anna)

```r
library(catviz)
library(did)

# 1. Visualize with catviz
spec <- cat_spec(data, "id", "year", "g")
cat_plot_csdid(spec)

# 2. Estimate with did package
result <- att_gt(
  yname = "outcome",
  tname = "year",
  idname = "id",
  gname = "g",
  data = data
)

# 3. Aggregate and plot
agg_result <- aggte(result, type = "dynamic")
ggdid(agg_result)
```

### With `fixest` (two-way fixed effects)

```r
library(catviz)
library(fixest)

# 1. Visualize treatment structure
spec <- cat_spec(data, "id", "year", "g")
cat_plot_csdid(spec)

# 2. Estimate with Sun-Abraham interactions
feols(outcome ~ sunab(g, year) | id + year, data = data)
```

---

## Tips and Best Practices

### 1. **Always visualize before estimating**
Create your CAT first to verify:
- Treatment timing is correct
- Cohorts are properly defined
- Sample sizes are reasonable
- Comparison groups exist

### 2. **Use meaningful variable names**
```r
# Good
cat_spec(data, id = "hospital_id", time = "year", g = "expansion_year")

# Avoid
cat_spec(data, id = "x1", time = "x2", g = "x3")
```

### 3. **Check for empty cells**
```r
cat_counts(spec)
# Look for cohorts with n=0 or very small samples
```

### 4. **Save high-resolution plots**
```r
# For publications
cat_plot_ddd(spec, save_plot = "figure1.png")  # Default: 400 DPI

# For presentations
ggsave("slide.png", p, width = 12, height = 8, dpi = 150)
```

### 5. **Document your tree in papers**
Include your CAT in the paper with a caption like:
> "Figure 1 shows the Causal Assignment Tree for our staggered DiD design. Letters A-E denote treatment cohorts in chronological order, while F represents the never-treated comparison group."

---

## Troubleshooting

### Common Issues

**Q: My tree shows cut-off labels**  
A: Update to the latest version of `catviz`. We've fixed all cut-off issues in v1.1+.

**Q: I get "No treated cohorts detected"**  
A: Check that your `g` column has finite values for treated units and `Inf` for never-treated units.

**Q: The tree is too wide/narrow**  
A: The plot width automatically adjusts. For manual control:
```r
p <- cat_plot_csdid(spec)
ggsave("my_cat.png", p, width = 20, height = 10)  # Adjust width
```

**Q: How do I handle continuous treatment?**  
A: `catviz` is designed for discrete treatment timing. For continuous treatment, discretize into cohorts first.

---

## Citation

If you use `catviz` in your research, please cite:

```bibtex
@misc{kilanko2025catviz,
  author = {Kilanko, Victor},
  title = {catviz: Visualizing Causal Assignment Trees for DiD, CSDiD, and DDD},
  year = {2025},
  publisher = {GitHub},
  url = {https://github.com/VictorKilanko/catviz}
}
```

---

## Contributing

Contributions are welcome! Please feel free to:
- Report bugs via [GitHub Issues](https://github.com/VictorKilanko/catviz/issues)
- Suggest features
- Submit pull requests

---

## License

MIT License. See [LICENSE](LICENSE) file for details.

---

## References

- Callaway, B., & Sant'Anna, P. H. (2021). Difference-in-differences with multiple time periods. *Journal of Econometrics*, 225(2), 200-230.
- Goodman-Bacon, A. (2021). Difference-in-differences with variation in treatment timing. *Journal of Econometrics*, 225(2), 254-277.
- Ortiz-Villavicencio, L., & Sant'Anna, P. H. C. (2025). Difference-in-Difference-in-Differences. Working Paper.

---

## Support

For questions or support:
- 📧 Email: victorkilanko@gmail.com
- 🐛 Issues: [GitHub Issues](https://github.com/VictorKilanko/catviz/issues)
- 📖 Documentation: [Package Website](https://victorkilanko.github.io/catviz)

---

**Made with ❤️ for transparent causal inference**
