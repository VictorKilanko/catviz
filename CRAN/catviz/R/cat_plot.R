

#' Plot DDD-style Causal Assignment Tree (cohorts x subgroup) - IMPROVED VERSION
#'
#' This version uses optimized spacing to prevent node overlap and create
#' a publication-quality visualization.
#'
#' @param spec A `cat_spec` object with a subgroup variable (DDD setup).
#' @param counts Logical; include sample size counts in node labels (default TRUE).
#' @param save_plot Optional file path for saving the plot (PNG, PDF, etc.).
#'
#' @return A ggplot object representing the DDD Causal Assignment Tree.
#' @export
cat_plot_ddd <- function(spec,
                         counts    = TRUE,
                         save_plot = NULL) {

  d      <- spec$data
  id_col <- spec$meta$id
  g_col  <- spec$meta$g
  p_col  <- spec$meta$subgroup

  if (is.null(p_col)) {
    stop("DDD design requires a subgroup variable (`subgroup` in cat_spec()).")
  }

  if (!all(c(".g", ".subgroup", ".NT") %in% names(d))) {
    stop("spec$data must contain .g, .subgroup, and .NT. Did you run cat_spec()?")
  }

  # -------------------------------------------------------------
  # 1. Identify cohorts and build letter mapping for leaves
  # -------------------------------------------------------------
  never_vals <- spec$meta$never_treated_values %||% c(0, Inf)

  is_nt  <- d$.NT == 1L | d[[g_col]] %in% never_vals
  is_trt <- !is_nt

  g_vals <- sort(unique(d[[g_col]][is_trt & is.finite(d[[g_col]])]))
  n_coh  <- length(g_vals)

  if (n_coh == 0L) {
    stop("No treated cohorts detected (all units appear to be never-treated).")
  }

  # All (g, Q) pairs for treated units: for each g, Q=1 first then Q=0
  treated_pairs <- tidyr::expand_grid(
    g_val = g_vals,
    Q     = c(1L, 0L)
  )

  n_pairs <- nrow(treated_pairs)
  letters_needed <- n_pairs + 2L  # +2 for NT Q=1 and Q=0

  if (letters_needed > length(LETTERS)) {
    warning("More than 26 (g, Q) + NT leaves; letter labels will recycle.")
  }

  letter_vec <- rep(LETTERS, length.out = letters_needed)

  treated_pairs <- treated_pairs |>
    dplyr::mutate(letter = letter_vec[seq_len(n_pairs)])

  # last two letters for NT Q=1 and Q=0
  letter_nt_Q1 <- letter_vec[n_pairs + 1L]
  letter_nt_Q0 <- letter_vec[n_pairs + 2L]

  # -------------------------------------------------------------
  # 2. Construct node names
  # -------------------------------------------------------------
  root_name <- "All Units"
  nt_node   <- "Never-Treated (g=Inf)"
  trt_node  <- "Treated Cohorts"

  # cohort internal nodes (no letters, just g labels)
  cohort_nodes <- tibble::tibble(
    g_val    = g_vals,
    node_name = paste0("g = ", g_val)
  )

  # treated leaves: Q=1(A), Q=0(B), ...
  treated_pairs <- treated_pairs |>
    dplyr::mutate(
      leaf_name = paste0("Q = ", Q, " (", letter, ")")
    )

  # never-treated leaves
  leaf_nt_Q1 <- paste0("Q = 1 (", letter_nt_Q1, ")")
  leaf_nt_Q0 <- paste0("Q = 0 (", letter_nt_Q0, ")")

  # -------------------------------------------------------------
  # 3. Compute counts for all nodes
  # -------------------------------------------------------------
  n_ids <- function(idx) dplyr::n_distinct(d[[id_col]][idx])

  subg <- d$.subgroup
  Q1   <- !is.na(subg) & subg == 1L
  Q0   <- !is.na(subg) & subg == 0L

  # Internal nodes
  internal_counts <- tibble::tibble(
    name = c(root_name,
             nt_node,
             trt_node,
             cohort_nodes$node_name),
    n = c(
      n_ids(rep(TRUE, nrow(d))),           # all units
      n_ids(is_nt),                        # never-treated
      n_ids(is_trt),                       # treated cohorts
      vapply(
        cohort_nodes$g_val,
        function(gv) n_ids(is_trt & d[[g_col]] == gv),
        FUN.VALUE = integer(1)
      )
    )
  )

  # Leave counts: NT first
  leaf_counts <- tibble::tibble(
    name = c(leaf_nt_Q1, leaf_nt_Q0),
    n    = c(
      n_ids(is_nt & Q1),
      n_ids(is_nt & Q0)
    )
  )

  # Treated leaves for each (g, Q)
  for (k in seq_len(n_pairs)) {
    gv   <- treated_pairs$g_val[k]
    qval <- treated_pairs$Q[k]
    nm   <- treated_pairs$leaf_name[k]

    idx <- is_trt & d[[g_col]] == gv & if (qval == 1L) Q1 else Q0

    leaf_counts <- dplyr::bind_rows(
      leaf_counts,
      tibble::tibble(name = nm, n = n_ids(idx))
    )
  }

  # Combine counts
  nodes_counts <- tibble::tibble(name = c(
    root_name,
    nt_node,
    trt_node,
    cohort_nodes$node_name,
    leaf_nt_Q1,
    leaf_nt_Q0,
    treated_pairs$leaf_name
  )) |>
    dplyr::distinct() |>
    dplyr::left_join(internal_counts, by = "name") |>
    dplyr::left_join(leaf_counts,     by = "name") |>
    dplyr::mutate(n = dplyr::coalesce(n.x, n.y, 0L)) |>
    dplyr::select(name, n)

  # -------------------------------------------------------------
  # 4. IMPROVED LAYOUT: Optimized spacing for publication quality
  # -------------------------------------------------------------

  # Vertical spacing - MORE GENEROUS for readability
  y_root   <- 0
  y_level1 <- -1.5    # Increased from -1.0
  y_cohort <- -3.2    # Increased from -2.0
  y_leaf   <- -5.0    # Increased from -3.2

  # Horizontal spacing - Calculate based on number of leaves
  n_leaves <- n_pairs + 2L

  # Use wider spacing for better readability
  # Minimum spacing of 1.5 units between leaves
  leaf_spacing <- max(1.5, 12 / n_leaves)  # Adaptive spacing

  # Create leaf positions with proper spacing
  all_leaf_names <- c(treated_pairs$leaf_name, leaf_nt_Q1, leaf_nt_Q0)

  # Center the leaves around x=0
  total_width <- (n_leaves - 1) * leaf_spacing
  x_start <- -total_width / 2
  x_all_leaves <- seq(from = x_start,
                      to = x_start + total_width,
                      length.out = n_leaves)

  # Create mapping of leaf names to x positions
  x_leaf_map <- tibble::tibble(
    name = all_leaf_names,
    x_new = x_all_leaves
  )

  # Calculate cohort node positions (centered over their leaves)
  x_cohort_map <- treated_pairs |>
    dplyr::left_join(x_leaf_map, by = c("leaf_name" = "name")) |>
    dplyr::group_by(g_val) |>
    dplyr::summarise(x_new = mean(x_new), .groups = "drop") |>
    dplyr::mutate(name = paste0("g = ", g_val)) |>
    dplyr::select(name, x_new)

  # NT node centered over its two leaves
  nt_leaf_indices <- (n_pairs + 1):n_leaves
  x_nt_center <- mean(x_all_leaves[nt_leaf_indices])

  # Treated cohorts node centered over all cohort nodes
  x_trt <- mean(x_cohort_map$x_new)

  # Root node centered over everything
  x_root <- 0  # Center at origin

  # Build node position table
  nodes_pos <- dplyr::bind_rows(
    # root
    tibble::tibble(
      name = root_name,
      x = x_root,
      y = y_root
    ),
    # level 1: Give some horizontal separation
    tibble::tibble(
      name = c(trt_node, nt_node),
      x = c(x_trt, x_nt_center),
      y = y_level1
    ),
    # cohort nodes
    x_cohort_map |>
      dplyr::mutate(
        name = name,
        x = x_new,
        y = y_cohort
      ) |>
      dplyr::select(name, x, y),
    # treated leaves
    treated_pairs |>
      dplyr::mutate(
        name = leaf_name
      ) |>
      dplyr::left_join(x_leaf_map, by = "name") |>
      dplyr::mutate(
        x = x_new,
        y = y_leaf
      ) |>
      dplyr::select(name, x, y),
    # NT leaves
    tibble::tibble(
      name = c(leaf_nt_Q1, leaf_nt_Q0),
      x = x_leaf_map$x_new[x_leaf_map$name %in% c(leaf_nt_Q1, leaf_nt_Q0)],
      y = y_leaf
    )
  )

  # -------------------------------------------------------------
  # 5. Edges (clean parent->child segments)
  # -------------------------------------------------------------
  edges <- dplyr::bind_rows(
    # root to level 1
    tibble::tibble(
      from = root_name,
      to   = c(trt_node, nt_node)
    ),
    # treated cohorts node to each cohort g node
    tibble::tibble(
      from = trt_node,
      to   = cohort_nodes$node_name
    ),
    # each cohort g node to its Q leaves
    cohort_nodes |>
      dplyr::inner_join(treated_pairs, by = "g_val") |>
      dplyr::transmute(
        from = node_name,
        to   = leaf_name
      ),
    # NT node to NT leaves
    tibble::tibble(
      from = nt_node,
      to   = c(leaf_nt_Q1, leaf_nt_Q0)
    )
  )

  # Join edge positions
  edges_pos <- edges |>
    dplyr::left_join(
      nodes_pos |> dplyr::rename(x_from = x, y_from = y),
      by = c("from" = "name")
    ) |>
    dplyr::left_join(
      nodes_pos |> dplyr::rename(x_to = x, y_to = y),
      by = c("to" = "name")
    )

  # -------------------------------------------------------------
  # 6. Merge positions with counts & roles
  # -------------------------------------------------------------
  nodes <- nodes_pos |>
    dplyr::left_join(nodes_counts, by = "name")

  # roles for fill colours
  nodes$role <- "none"
  nodes$role[nodes$name == nt_node |
               nodes$name %in% c(leaf_nt_Q1, leaf_nt_Q0)] <- "control"
  nodes$role[nodes$name == trt_node |
               nodes$name %in% cohort_nodes$node_name |
               nodes$name %in% treated_pairs$leaf_name]   <- "treated"

  # final labels
  nodes$label <- if (counts) {
    glue::glue("{nodes$name}\n(n={nodes$n})")
  } else {
    nodes$name
  }

  # subtitle
  subtitle_text <- paste0(
    "Treatment Years (g): ",
    paste(g_vals, collapse = ", ")
  )

  # -------------------------------------------------------------
  # 7. IMPROVED PLOT with better aesthetics
  # -------------------------------------------------------------
  p <- ggplot2::ggplot() +
    # Edges with better styling
    ggplot2::geom_segment(
      data = edges_pos,
      ggplot2::aes(x = x_from, y = y_from, xend = x_to, yend = y_to),
      colour = "grey60",
      linewidth = 0.5,
      alpha = 0.7
    ) +
    # Nodes with improved styling
    ggplot2::geom_label(
      data = nodes,
      ggplot2::aes(x = x, y = y, label = label, fill = role),
      label.padding = grid::unit(0.4, "lines"),
      label.r       = grid::unit(0.3, "lines"),
      size          = 3.8,
      label.size    = 0.3,
      colour        = "black",
      lineheight    = 1.0,
      fontface      = "plain"
    ) +
    # Improved color scheme
    ggplot2::scale_fill_manual(values = c(
      none    = "#FFFFFF",
      control = "#D6EAF8",  # Softer blue
      treated = "#FADBD8"   # Softer red
    )) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(
      title    = "Causal Assignment Tree (DDD)",
      subtitle = subtitle_text,
      x = NULL, y = NULL
    ) +
    ggplot2::theme(
      panel.grid      = ggplot2::element_blank(),
      axis.text       = ggplot2::element_blank(),
      axis.ticks      = ggplot2::element_blank(),
      plot.title      = ggplot2::element_text(hjust = 0.5, size = 16, face = "bold"),
      plot.subtitle   = ggplot2::element_text(hjust = 0.5, size = 10, colour = "grey40"),
      legend.position = "none",
      plot.margin     = grid::unit(c(1, 1, 1, 1), "cm")
    )

  if (!is.null(save_plot)) {
    # Calculate appropriate width based on number of leaves
    plot_width <- max(14, n_leaves * 1.2)
    ggplot2::ggsave(save_plot, p, width = plot_width, height = 9, dpi = 400)
    message("Plot saved to: ", save_plot)
  }

  return(p)
}



# ==============================================================================
# IMPROVED CSDID AND 2x2 DID PLOTTING FUNCTIONS
# Publication-quality visualizations with no node overlap or cut-offs
# ==============================================================================

###_____________________________________________________________________________
###-----------------------------------------------------------------------------
###_____________________________________________________________________________
# IMPROVED CSDID PLOT
###_____________________________________________________________________________

#' Plot CSDiD Causal Assignment Tree (IMPROVED - No Cut-offs)
#'
#' Tree structure:
#'   All Units
#'     |-- Treated Cohorts
#'     |     |-- g = g1 (A)
#'     |     |-- g = g2 (B)
#'     |     |-- g = g3 (C)
#'     |     +-- ...
#'     +-- Never-Treated (g = Inf) (last letter)
#'
#' Letters A,B,C,... assigned in chronological order of g.
#'
#' @param spec A cat_spec object (CSDID setup: no subgroup).
#' @param counts Logical; include counts in node labels (default TRUE)
#' @param save_plot Optional file path for plot (PNG, PDF, etc.)
#'
#' @return A ggplot object representing the CSDID Causal Assignment Tree.
#' @export
cat_plot_csdid <- function(spec,
                           counts    = TRUE,
                           save_plot = NULL) {

  # Extract variables
  d      <- spec$data
  id_col <- spec$meta$id
  g_col  <- spec$meta$g

  if (!all(c(".g", ".NT") %in% names(d))) {
    stop("spec$data must contain .g and .NT. Did you run the updated cat_spec()?")
  }

  # Identify treated cohorts
  never_vals <- spec$meta$never_treated_values %||% c(0, Inf)

  is_nt  <- d$.NT == 1L | d[[g_col]] %in% never_vals
  is_trt <- !is_nt

  # Treated cohort values in chronological order
  g_vals <- sort(unique(d[[g_col]][is_trt & is.finite(d[[g_col]])]))
  n_coh  <- length(g_vals)

  if (n_coh == 0L) stop("No treated cohorts detected.")

  # Letter labels A, B, C, ...
  letters_needed <- n_coh + 1   # +1 for never treated
  letter_vec <- rep(LETTERS, length.out = letters_needed)

  letter_nt <- letter_vec[letters_needed]
  letter_tr <- letter_vec[1:n_coh]

  # Cohort node names
  cohort_nodes <- tibble::tibble(
    g_val = g_vals,
    node_name = paste0("g = ", g_vals, " (", letter_tr, ")")
  )

  # Define nodes
  root_name <- "All Units"
  nt_node   <- paste0("Never-Treated (g=Inf) (", letter_nt, ")")
  trt_node  <- "Treated Cohorts"

  # Count helper
  n_ids <- function(idx) dplyr::n_distinct(d[[id_col]][idx])

  # Internal counts
  internal_counts <- tibble::tibble(
    name = c(root_name, nt_node, trt_node, cohort_nodes$node_name),
    n = c(
      n_ids(rep(TRUE, nrow(d))),   # all units
      n_ids(is_nt),                # never-treated
      n_ids(is_trt),               # treated
      vapply(cohort_nodes$g_val,
             function(gv) n_ids(d[[g_col]] == gv & is_trt),
             FUN.VALUE = integer(1))
    )
  )

  # Final node table
  nodes <- tibble::tibble(
    name = c(root_name, trt_node, nt_node, cohort_nodes$node_name)
  ) |>
    dplyr::left_join(internal_counts, by = "name") |>
    dplyr::mutate(n = dplyr::coalesce(n, 0L))

  # Roles for fill colors
  nodes$role <- "none"
  nodes$role[nodes$name == nt_node] <- "control"
  nodes$role[nodes$name == trt_node |
               nodes$name %in% cohort_nodes$node_name] <- "treated"

  # Labels
  nodes$label <- if (counts) {
    glue::glue("{nodes$name}\n(n={nodes$n})")
  } else nodes$name

  # ---------------------------------------------------------------
  # IMPROVED LAYOUT: Manual positioning to prevent cut-offs
  # ---------------------------------------------------------------

  # Vertical levels (more generous spacing)
  y_root   <- 0
  y_level1 <- -1.8    # Increased from -1.2
  y_cohort <- -3.8    # Increased from -2.5

  # Horizontal spacing
  n_leaves <- n_coh + 1  # cohort nodes + never-treated

  # Calculate adaptive spacing
  leaf_spacing <- max(2.0, 15 / n_leaves)  # Minimum 2 units between nodes

  # Create leaf positions (cohort nodes)
  total_width <- (n_leaves - 1) * leaf_spacing
  x_start <- -total_width / 2
  x_cohort_positions <- seq(from = x_start,
                            to = x_start + total_width,
                            length.out = n_leaves)

  # Assign positions
  x_cohort_map <- tibble::tibble(
    node_name = c(cohort_nodes$node_name, nt_node),
    x_pos = x_cohort_positions
  )

  # Treated cohorts node (center over cohort nodes only, not including NT)
  x_trt <- mean(x_cohort_positions[1:n_coh])

  # Never-treated position (already in x_cohort_map)
  x_nt <- x_cohort_positions[n_leaves]

  # Root node (centered)
  x_root <- 0

  # Build position table
  nodes_pos <- dplyr::bind_rows(
    # Root
    tibble::tibble(
      name = root_name,
      x = x_root,
      y = y_root
    ),
    # Level 1
    tibble::tibble(
      name = c(trt_node, nt_node),
      x = c(x_trt, x_nt),
      y = y_level1
    ),
    # Cohort nodes
    cohort_nodes |>
      dplyr::left_join(x_cohort_map, by = "node_name") |>
      dplyr::mutate(
        name = node_name,
        x = x_pos,
        y = y_cohort
      ) |>
      dplyr::select(name, x, y)
  )

  # ---------------------------------------------------------------
  # Build edges
  # ---------------------------------------------------------------
  edges <- dplyr::bind_rows(
    # Root to level 1
    tibble::tibble(
      from = root_name,
      to   = c(trt_node, nt_node)
    ),
    # Treated cohorts node to each cohort
    tibble::tibble(
      from = trt_node,
      to   = cohort_nodes$node_name
    )
  )

  # Join edge positions
  edges_pos <- edges |>
    dplyr::left_join(
      nodes_pos |> dplyr::rename(x_from = x, y_from = y),
      by = c("from" = "name")
    ) |>
    dplyr::left_join(
      nodes_pos |> dplyr::rename(x_to = x, y_to = y),
      by = c("to" = "name")
    )

  # ---------------------------------------------------------------
  # Merge positions with counts & roles
  # ---------------------------------------------------------------
  nodes <- nodes_pos |>
    dplyr::left_join(nodes, by = "name")

  # Subtitle
  subtitle_text <- paste0("Treatment Years (g): ", paste(g_vals, collapse = ", "))

  # ---------------------------------------------------------------
  # Calculate plot bounds with padding
  # ---------------------------------------------------------------
  x_range <- range(nodes$x)
  y_range <- range(nodes$y)

  # Add padding (20% on each side)
  x_padding <- diff(x_range) * 0.25
  y_padding <- diff(y_range) * 0.20

  xlim_plot <- c(x_range[1] - x_padding, x_range[2] + x_padding)
  ylim_plot <- c(y_range[1] - y_padding, y_range[2] + y_padding)

  # ---------------------------------------------------------------
  # IMPROVED PLOT with proper coordinate limits
  # ---------------------------------------------------------------
  p <- ggplot2::ggplot() +
    # Edges
    ggplot2::geom_segment(
      data = edges_pos,
      ggplot2::aes(x = x_from, y = y_from, xend = x_to, yend = y_to),
      colour = "grey60",
      linewidth = 0.5,
      alpha = 0.7
    ) +
    # Nodes
    ggplot2::geom_label(
      data = nodes,
      ggplot2::aes(x = x, y = y, label = label, fill = role),
      label.padding = grid::unit(0.4, "lines"),
      label.r       = grid::unit(0.3, "lines"),
      size          = 3.8,
      label.size    = 0.3,
      colour        = "black",
      lineheight    = 1.0,
      fontface      = "plain"
    ) +
    # Colors
    ggplot2::scale_fill_manual(values = c(
      none    = "#FFFFFF",
      control = "#D6EAF8",
      treated = "#FADBD8"
    )) +
    # SET COORDINATE LIMITS to prevent cut-offs
    ggplot2::coord_cartesian(xlim = xlim_plot, ylim = ylim_plot, expand = FALSE) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(
      title    = "Causal Assignment Tree (CSDiD)",
      subtitle = subtitle_text,
      x = NULL, y = NULL
    ) +
    ggplot2::theme(
      panel.grid      = ggplot2::element_blank(),
      axis.text       = ggplot2::element_blank(),
      axis.ticks      = ggplot2::element_blank(),
      plot.title      = ggplot2::element_text(hjust = 0.5, size = 16, face = "bold"),
      plot.subtitle   = ggplot2::element_text(hjust = 0.5, size = 10, colour = "grey40"),
      legend.position = "none",
      plot.margin     = grid::unit(c(1, 1, 1, 1), "cm")
    )

  if (!is.null(save_plot)) {
    # Calculate appropriate width
    plot_width <- max(12, n_leaves * 2)
    ggplot2::ggsave(save_plot, p, width = plot_width, height = 8, dpi = 400)
    message("CSDiD plot saved to: ", save_plot)
  }

  return(p)
}


###_____________________________________________________________________________
###-----------------------------------------------------------------------------
###_____________________________________________________________________________
# IMPROVED 2x2 DID PLOT
###_____________________________________________________________________________

#' Plot 2x2 DID Causal Assignment Tree (IMPROVED - No Cut-offs)
#'
#' Structure:
#'   All Units
#'     |-- Treated (A)
#'     |     |-- Pre (C)
#'     |     +-- Post (D)
#'     +-- Control (B)
#'           |-- Pre (E)
#'           +-- Post (F)
#'
#' @param spec A cat_spec object (standard DID with no staggered timing).
#' @param counts Logical; include sample size counts in node labels.
#' @param save_plot Optional path to save.
#'
#' @return A ggplot object.
#' @export
cat_plot_did <- function(spec,
                         counts    = TRUE,
                         save_plot = NULL) {

  d        <- spec$data
  id_col   <- spec$meta$id
  time_col <- spec$meta$time
  g_col    <- spec$meta$g

  if (!("treated" %in% names(d))) {
    # Infer treated status: g = finite -> treated, g = Inf -> control
    d$treated <- ifelse(is.finite(d[[g_col]]), 1L, 0L)
  }

  # Identify pre and post relative to the single adoption date
  g_val <- unique(d[[g_col]][is.finite(d[[g_col]])])
  if (length(g_val) != 1) {
    stop("2x2 DID requires exactly one treated group (one finite g value).")
  }
  g_star <- g_val[1]

  d$.PrePost <- ifelse(d[[time_col]] < g_star, "Pre", "Post")
  d$.PrePost[is.na(d$.PrePost)] <- "Pre"

  # Node names
  root_name   <- "All Units"
  t_node      <- "Treated (A)"
  c_node      <- "Control (B)"
  leaf_T_Pre  <- "Pre (C)"
  leaf_T_Post <- "Post (D)"
  leaf_C_Pre  <- "Pre (E)"
  leaf_C_Post <- "Post (F)"

  # Helper to count distinct individuals
  n_ids <- function(idx) dplyr::n_distinct(d[[id_col]][idx])

  # Internal counts
  internal <- tibble::tibble(
    name = c(root_name, t_node, c_node),
    n = c(
      n_ids(TRUE),
      n_ids(d$treated == 1),
      n_ids(d$treated == 0)
    )
  )

  # Leaves
  leaf_counts <- tibble::tibble(
    name = c(
      leaf_T_Pre, leaf_T_Post,
      leaf_C_Pre, leaf_C_Post
    ),
    n = c(
      n_ids(d$treated == 1 & d$.PrePost == "Pre"),
      n_ids(d$treated == 1 & d$.PrePost == "Post"),
      n_ids(d$treated == 0 & d$.PrePost == "Pre"),
      n_ids(d$treated == 0 & d$.PrePost == "Post")
    )
  )

  nodes <- tibble::tibble(
    name = c(root_name, t_node, c_node,
             leaf_T_Pre, leaf_T_Post, leaf_C_Pre, leaf_C_Post)
  ) |>
    dplyr::left_join(internal, by = "name") |>
    dplyr::left_join(leaf_counts, by = "name") |>
    dplyr::mutate(n = dplyr::coalesce(n.x, n.y, 0L)) |>
    dplyr::select(name, n)

  # Role colors
  nodes$role <- "none"
  nodes$role[nodes$name %in% c(t_node, leaf_T_Pre, leaf_T_Post)] <- "treated"
  nodes$role[nodes$name %in% c(c_node, leaf_C_Pre, leaf_C_Post)] <- "control"

  # Node labels
  nodes$label <- if (counts) {
    glue::glue("{nodes$name}\n(n={nodes$n})")
  } else {
    nodes$name
  }

  # ---------------------------------------------------------------
  # IMPROVED LAYOUT: Manual positioning to prevent cut-offs
  # ---------------------------------------------------------------

  # Vertical levels (generous spacing)
  y_root   <- 0
  y_level1 <- -1.8
  y_leaf   <- -3.8

  # Horizontal positions (4 leaves total)
  x_leaf_T_Pre  <- -3
  x_leaf_T_Post <- -1
  x_leaf_C_Pre  <- 1
  x_leaf_C_Post <- 3

  # Parent nodes (centered over their children)
  x_treated <- mean(c(x_leaf_T_Pre, x_leaf_T_Post))
  x_control <- mean(c(x_leaf_C_Pre, x_leaf_C_Post))
  x_root    <- 0

  # Build position table
  nodes_pos <- tibble::tibble(
    name = c(
      root_name,
      t_node, c_node,
      leaf_T_Pre, leaf_T_Post, leaf_C_Pre, leaf_C_Post
    ),
    x = c(
      x_root,
      x_treated, x_control,
      x_leaf_T_Pre, x_leaf_T_Post, x_leaf_C_Pre, x_leaf_C_Post
    ),
    y = c(
      y_root,
      y_level1, y_level1,
      y_leaf, y_leaf, y_leaf, y_leaf
    )
  )

  # Build edges
  edges <- tibble::tribble(
    ~from,      ~to,
    root_name,  t_node,
    root_name,  c_node,
    t_node,     leaf_T_Pre,
    t_node,     leaf_T_Post,
    c_node,     leaf_C_Pre,
    c_node,     leaf_C_Post
  )

  # Join edge positions
  edges_pos <- edges |>
    dplyr::left_join(
      nodes_pos |> dplyr::rename(x_from = x, y_from = y),
      by = c("from" = "name")
    ) |>
    dplyr::left_join(
      nodes_pos |> dplyr::rename(x_to = x, y_to = y),
      by = c("to" = "name")
    )

  # Merge positions with counts & roles
  nodes <- nodes_pos |>
    dplyr::left_join(nodes, by = "name")

  # ---------------------------------------------------------------
  # Calculate plot bounds with padding
  # ---------------------------------------------------------------
  x_range <- range(nodes$x)
  y_range <- range(nodes$y)

  # Add padding
  x_padding <- diff(x_range) * 0.15
  y_padding <- diff(y_range) * 0.15

  xlim_plot <- c(x_range[1] - x_padding, x_range[2] + x_padding)
  ylim_plot <- c(y_range[1] - y_padding, y_range[2] + y_padding)

  # ---------------------------------------------------------------
  # IMPROVED PLOT
  # ---------------------------------------------------------------
  p <- ggplot2::ggplot() +
    # Edges
    ggplot2::geom_segment(
      data = edges_pos,
      ggplot2::aes(x = x_from, y = y_from, xend = x_to, yend = y_to),
      colour = "grey60",
      linewidth = 0.5,
      alpha = 0.7
    ) +
    # Nodes
    ggplot2::geom_label(
      data = nodes,
      ggplot2::aes(x = x, y = y, label = label, fill = role),
      label.padding = grid::unit(0.4, "lines"),
      label.r       = grid::unit(0.3, "lines"),
      size          = 3.8,
      label.size    = 0.3,
      colour        = "black",
      lineheight    = 1.0,
      fontface      = "plain"
    ) +
    # Colors
    ggplot2::scale_fill_manual(values = c(
      none    = "#FFFFFF",
      control = "#D6EAF8",
      treated = "#FADBD8"
    )) +
    # SET COORDINATE LIMITS to prevent cut-offs
    ggplot2::coord_cartesian(xlim = xlim_plot, ylim = ylim_plot, expand = FALSE) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::labs(
      title    = "Causal Assignment Tree (2x2 DiD)",
      subtitle = paste0("Single treatment time g = ", g_star,
                        " | Leaves: C=TreatPre, D=TreatPost, E=CtrlPre, F=CtrlPost"),
      x = NULL, y = NULL
    ) +
    ggplot2::theme(
      panel.grid      = ggplot2::element_blank(),
      axis.text       = ggplot2::element_blank(),
      axis.ticks      = ggplot2::element_blank(),
      plot.title      = ggplot2::element_text(hjust = 0.5, size = 16, face = "bold"),
      plot.subtitle   = ggplot2::element_text(hjust = 0.5, size = 10, colour = "grey40"),
      legend.position = "none",
      plot.margin     = grid::unit(c(1, 1, 1, 1), "cm")
    )

  if (!is.null(save_plot)) {
    ggplot2::ggsave(save_plot, p, width = 12, height = 8, dpi = 400)
    message("DiD plot saved to: ", save_plot)
  }

  return(p)
}


