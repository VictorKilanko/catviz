# catviz: Causal Assignment Tree Visualization for Staggered DiD and Related Designs

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
