#' Plot the Causal Assignment Tree (CAT) with publication-quality styling
#'
#' @param spec A cat_spec object (labeled or not)
#' @param counts Logical; include counts in node labels (default = TRUE)
#' @param highlight Logical; color nodes by role (treated/control/both/none)
#' @param save_plot Optional file path (e.g., "CAT_plot.png" or "CAT_plot.pdf")
#' @param save_table Optional CSV path to save subgroup summary table
#' @return A list with elements: plot (ggplot) and summary (data.frame or NULL)
#' @export
cat_plot_tree <- function(spec,
                          counts = TRUE,
                          highlight = TRUE,
                          save_plot = NULL,
                          save_table = NULL) {

  d <- spec$data
  id_col   <- spec$meta$id
  time_col <- spec$meta$time
  g_col    <- spec$meta$g
  p_col    <- spec$meta$subgroup

  # ---- canonical labels based on .node ----
  node_vals <- unique(d$.node)
  find_node <- function(patterns, fallback)
    node_vals[which(Reduce(`&`, lapply(patterns, grepl, node_vals, fixed = TRUE)))[1]] %||% fallback

  n1 <- find_node(c("t<g","p=0"), "(1) t<g, p=0")
  n2 <- find_node(c("t<g","p=1"), "(2) t<g, p=1")
  n3 <- find_node(c("t≥g","p=0"), "(3) t≥g, p=0")
  n4 <- find_node(c("t≥g","p=1"), "(4) t≥g, p=1")
  n5 <- find_node(c("NT","p=0"),  "(5) NT, p=0")
  n6 <- find_node(c("NT","p=1"),  "(6) NT, p=1")

  # ---- edges ----
  edges <- dplyr::tribble(
    ~from,                  ~to,
    "All Groups",           "Treated Groups",
    "All Groups",           "Never-Treated (g=∞)",
    "Treated Groups",       "t<g",
    "Treated Groups",       "t≥g",
    "t<g",                  n1,
    "t<g",                  n2,
    "t≥g",                  n3,
    "t≥g",                  n4,
    "Never-Treated (g=∞)",  n5,
    "Never-Treated (g=∞)",  n6
  )
  g <- igraph::graph_from_data_frame(edges, directed = TRUE)

  # ---- counts ----
  is_trt   <- is.finite(d[[g_col]]) & d[[g_col]] > 0
  is_never <- !is.finite(d[[g_col]]) | d[[g_col]] == 0
  is_pre   <- is.finite(d[[g_col]]) & d[[time_col]] <  d[[g_col]]
  is_post  <- is.finite(d[[g_col]]) & d[[time_col]] >= d[[g_col]]

  internal_counts <- tibble::tibble(
    name = c("All Groups","Treated Groups","Never-Treated (g=∞)","t<g","t≥g"),
    n = c(
      dplyr::n_distinct(d[[id_col]]),
      dplyr::n_distinct(d[[id_col]][is_trt]),
      dplyr::n_distinct(d[[id_col]][is_never]),
      dplyr::n_distinct(d[[id_col]][is_pre]),
      dplyr::n_distinct(d[[id_col]][is_post])
    )
  )

  leaf_counts <- d |>
    dplyr::group_by(.node) |>
    dplyr::summarise(n = dplyr::n_distinct(.data[[id_col]]), .groups = "drop")

  nodes <- dplyr::tibble(name = igraph::V(g)$name) |>
    dplyr::left_join(internal_counts, by = "name") |>
    dplyr::left_join(leaf_counts, by = c("name" = ".node")) |>
    dplyr::mutate(n = dplyr::coalesce(n.x, n.y, 0L)) |>
    dplyr::select(name, n)

  # ---- color coding ----
  nodes$role <- "none"
  if (highlight && all(c(".treated",".control") %in% names(d))) {
    tag <- d |> dplyr::group_by(.node) |>
      dplyr::summarise(has_tr = any(.treated), has_ct = any(.control), .groups="drop")
    nodes <- nodes |>
      dplyr::left_join(tag, by = c("name" = ".node")) |>
      dplyr::mutate(role = dplyr::case_when(
        isTRUE(has_tr) & !isTRUE(has_ct) ~ "treated",
        !isTRUE(has_tr) & isTRUE(has_ct) ~ "control",
        isTRUE(has_tr) & isTRUE(has_ct)  ~ "both",
        TRUE ~ "none"))
  }

  nodes$label <- if (counts)
    glue::glue("{nodes$name}\n(n={nodes$n})") else nodes$name

  # --- Left-to-right layout (root on left)
  layout <- ggraph::create_layout(g, layout = "tree")
  layout <- layout |> dplyr::mutate(x = -x, y = y)  # flip horizontally
  layout <- dplyr::left_join(layout, nodes, by = "name")


  # ---- legend text ----
  years <- sort(unique(d[[g_col]][is.finite(d[[g_col]])]))
  subtitle_text <- if (length(years) > 1)
    glue::glue("Treatment years (g): {paste(years, collapse = ', ')}")
  else if (length(years) == 1)
    glue::glue("Treatment year (g): {years}")
  else "No finite treatment years detected."


  # ---- plot ----
  p <- ggraph::ggraph(layout) +
    ggraph::geom_edge_elbow(
      arrow = grid::arrow(length = grid::unit(3, "mm"), type = "closed"),
      edge_colour = "grey50", edge_width = 0.7
    ) +
    ggraph::geom_node_label(
      ggplot2::aes(x = x, y = y, label = label, fill = role),
      label.padding = grid::unit(0.4, "lines"),
      label.r       = grid::unit(0.25, "lines"),
      family = "",          # system font for publication
      fontface = "plain",        # ✅ plain text, not bold
      size = 4.2,                # slightly smaller for elegance
      label.size = 0.25,
      color = "black",
      lineheight = 1.1           # tighter line spacing looks cleaner
    ) +
    ggplot2::scale_fill_manual(values = c(
      none = "white",
      control = "#E4EEF8",
      treated = "#F6D4D2",
      both = "#E7DAF0"
    )) +
    ggplot2::coord_fixed(ratio = 1) +
    ggplot2::theme_minimal(base_family = "", base_size = 13) +
    ggplot2::labs(
      title = "Causal Assignment Tree (CAT)",
      subtitle = subtitle_text, x = NULL, y = NULL
    ) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text  = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(
        hjust = 0.5, size = 18, face = "bold"
      ),
      plot.subtitle = ggplot2::element_text(
        hjust = 0.5, size = 12, color = "grey35"
      ),
      legend.position = "none"
    )


  # ---- subgroup summary ----
  if (!is.null(p_col) && p_col %in% names(d)) {
    subgroup_summary <- d |>
      dplyr::filter(is.finite(.data[[g_col]]), !is.na(.data[[p_col]])) |>
      dplyr::group_by(.data[[g_col]], .data[[p_col]]) |>
      dplyr::summarise(n = dplyr::n_distinct(.data[[id_col]]), .groups = "drop") |>
      dplyr::rename(g = !!g_col, p = !!p_col) |>
      tidyr::pivot_wider(names_from = p, values_from = n,
                         names_prefix = "p_", values_fill = 0) |>
      dplyr::mutate(Total = rowSums(dplyr::across(dplyr::starts_with("p_")))) |>
      dplyr::arrange(g)
    message("\nSummary of treated groups by year and subgroup:")
    print(subgroup_summary, n = Inf)
  } else {
    subgroup_summary <- NULL
    message("\nNo subgroup variable (p) found. Skipping subgroup summary.")
  }

  if (!is.null(save_plot))
    ggplot2::ggsave(save_plot, p, width = 11, height = 7, dpi = 400)

  if (!is.null(save_table) && !is.null(subgroup_summary))
    readr::write_csv(subgroup_summary, save_table)

  list(plot = p, summary = subgroup_summary)
}
