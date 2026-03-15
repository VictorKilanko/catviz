# catviz 0.1.0

## Initial release

* `cat_spec()`: Build a Causal Assignment Tree specification from panel data
* `cat_label()`: Attach cohort letters and canonical labels to a spec
* `cat_plot_tree()`: Unified plot dispatcher — automatically selects DiD, CSDiD, or DDD tree
* `cat_plot_did()`: Publication-quality 2×2 DiD tree
* `cat_plot_csdid()`: Publication-quality CSDiD tree (Callaway–Sant'Anna staggered adoption)
* `cat_plot_ddd()`: Publication-quality DDD/DR-DDD tree with subgroup split
* `cat_counts()`: Count units or observations per CAT node
* `cat_balance_table()` / `cat_balance_plot()`: Covariate balance across nodes
* `cat_diag()`: Pretrend diagnostic plots (DR-DDD and CSDiD)
* `cat_att_equation()`: Returns the ATT formula implied by the tree
* `cat_save_png()`: Save a CAT plot to a high-resolution PNG
* Grayscale option (`grayscale = TRUE`) for black-and-white publications
