# catviz 0.1.0

## Initial release

### Core functions

* `cat_spec()`: Build a Causal Assignment Tree specification from panel data. Accepts `id`, `time`, `g`, optional `subgroup` (binary 0/1 for DDD), and optional `group_id` for clustered treatment assignment.
* `cat_label()`: Attach chronological letter labels (A, B, C, ...) and canonical node descriptors to a `cat_spec` object.
* `cat_counts()`: Count units or observations per CAT node.

### Visualization

* `cat_plot_tree()`: **Recommended entry point.** Unified plot dispatcher — automatically detects the design (2×2 DiD, CSDiD, or DR-DDD) from the `cat_spec` and calls the appropriate underlying function. Supports `grayscale = TRUE` for black-and-white publication output.
* `cat_plot_did()`: Publication-quality 2×2 DiD tree with pre/post split.
* `cat_plot_csdid()`: Publication-quality CSDiD tree for Callaway–Sant'Anna staggered adoption designs.
* `cat_plot_ddd()`: Publication-quality DR-DDD tree with cohort × subgroup node structure.
* `cat_save_png()`: Save any CAT plot to a high-resolution PNG file (default 400 DPI).

### Diagnostics

* `cat_diag()`: Unified diagnostic dispatcher. Method `"event"` returns event-time counts via `cat_event_table()`; `"csdid"` runs `cat_pt_csdid()` (parallel-trends gap plot); `"drddd"` runs `cat_pt_drddd()` (subgroup pre-trend plot).
* `cat_balance_table()`: Standardized mean differences (SMD) across CAT nodes or design groups (Treated vs. Never-Treated), with optional observation weights.
* `cat_balance_plot()`: Love plot for covariate balance from a `cat_balance_table()` result.
* `cat_att_equation()`: Returns the ATT formula implied by the tree design in plain text and LaTeX, along with a list of relevant nodes and an interpretive note. Supports `"drddd"` and `"csdid"` designs.
