# Static figures for the site, styled to the MacroFactor brand guidelines
# (https://macrofactor.com/brand-guidelines/): black and white at the core,
# DM Sans type, and the secondary colours for data marks only.
#
# Colour assignment (checked for colour-vision-deficiency separation):
# - two-category comparisons use blue and orange, which stay distinct under
#   protan, deutan and tritan simulation (OKLab delta E >= 31);
# - blue and purple are NOT distinguishable under protan/deutan vision, so the
#   four-domain palette always pairs colour with point shape.

# Neutrals and blue follow the MacroFactor Foundation site's design tokens
# (content-tertiary #5E5E5E, border #E8E8E8, foundation-blue #276EF1); the
# other accents are the brand guidelines' secondary colours.
MF <- list(
  black = "#000000", white = "#FFFFFF", ink = "#000000", muted = "#5E5E5E",
  grid = "#E8E8E8", neutral = "#8C8C8C",
  blue = "#276EF1", orange = "#CE5400", purple = "#A101C9", green = "#08C343"
)
# Unquoted on purpose: svglite writes single-quoted attributes, so a quoted
# family name would break the XML. Unquoted multi-word names are valid CSS.
MF_FONT_STACK <- "DM Sans, Helvetica, Arial, sans-serif"
MF_FONT_URL <- "https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,400;0,9..40,700;1,9..40,400&display=swap"

LOAD_COLOURS <- c("High load" = MF$blue, "Low load" = MF$orange)
STATUS_COLOURS <- c("Untrained" = MF$blue, "Trained" = MF$orange)
DOMAIN_COLOURS <- c(
  "Strength" = MF$blue, "Hypertrophy" = MF$orange,
  "Body Composition" = MF$green, "Absolute Muscular Endurance" = MF$purple,
  "Circumference" = MF$neutral
)
DOMAIN_SHAPES <- c(
  "Strength" = 16, "Hypertrophy" = 17, "Body Composition" = 15,
  "Absolute Muscular Endurance" = 18, "Circumference" = 4
)

theme_mf <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size, base_family = "sans") +
    ggplot2::theme(
      text = ggplot2::element_text(colour = MF$ink),
      plot.title = ggplot2::element_text(face = "bold", size = base_size * 1.25, margin = ggplot2::margin(b = 4)),
      plot.subtitle = ggplot2::element_text(colour = MF$muted, margin = ggplot2::margin(b = 10)),
      plot.title.position = "plot",
      plot.caption = ggplot2::element_text(colour = MF$muted, hjust = 0, size = base_size * 0.8),
      plot.caption.position = "plot",
      axis.text = ggplot2::element_text(colour = MF$muted),
      axis.title = ggplot2::element_text(colour = MF$ink),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = MF$grid, linewidth = 0.3),
      strip.text = ggplot2::element_text(face = "bold", hjust = 0, colour = MF$ink),
      legend.position = "top",
      legend.justification = "left",
      legend.title = ggplot2::element_blank(),
      legend.text = ggplot2::element_text(colour = MF$ink),
      plot.background = ggplot2::element_rect(fill = MF$white, colour = NA),
      plot.margin = ggplot2::margin(12, 16, 12, 12)
    )
}

# Write a ggplot to SVG atomically and deterministically, with the brand font
# stack in place of the locally resolved font so the page's DM Sans applies
# when the SVG is inlined.
write_svg <- function(plot, path, width = 8, height = 4.5) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(fileext = ".svg")
  svglite::svglite(tmp, width = width, height = height, bg = MF$white, fix_text_size = FALSE)
  on.exit(if (grDevices::dev.cur() > 1) grDevices::dev.off(), add = TRUE)
  print(plot)
  grDevices::dev.off()
  svg <- readLines(tmp, warn = FALSE, encoding = "UTF-8")
  svg <- gsub("font-family: *\"[^\"]*\";", paste0("font-family: ", MF_FONT_STACK, ";"), svg)
  svg <- gsub("font-family=\"[^\"]*\"", paste0("font-family=\"", MF_FONT_STACK, "\""), svg)
  # Load DM Sans inside the SVG itself, so it also applies when the file is
  # opened on its own (an <img> cannot load it; inlined SVGs use the page's).
  first_style <- which(grepl("<![CDATA[", svg, fixed = TRUE))[1]
  if (!is.na(first_style)) {
    svg[first_style] <- sub("<![CDATA[", paste0("<![CDATA[\n    @import url(", MF_FONT_URL, ");"), svg[first_style], fixed = TRUE)
  }
  write_lines_atomic(svg, path)
  path
}

g_axis_label <- "Standardized mean change (g)"

label_domain <- function(x) sub("Absolute Muscular Endurance", "Abs. muscular endurance", x, fixed = TRUE)

# ---- analysis figures ----------------------------------------------------------

# Pooled estimate per domain over the individual effect sizes ("orchard" style).
plot_pooled <- function(effect_sizes, pooled) {
  d <- dplyr::filter(effect_sizes, !.data$is_control, .data$domain %in% pooled$domain)
  set.seed(1)
  ggplot2::ggplot(d, ggplot2::aes(x = .data$yi, y = .data$domain)) +
    ggplot2::geom_vline(xintercept = 0, colour = MF$muted, linewidth = 0.4) +
    ggplot2::geom_jitter(ggplot2::aes(size = 1 / sqrt(.data$vi), colour = .data$domain), height = 0.18, width = 0, alpha = 0.35, stroke = 0) +
    ggplot2::geom_errorbar(data = pooled, ggplot2::aes(x = NULL, xmin = .data$pi_lb, xmax = .data$pi_ub), width = 0, linewidth = 0.5, colour = MF$ink) +
    ggplot2::geom_errorbar(data = pooled, ggplot2::aes(x = NULL, xmin = .data$ci_lb, xmax = .data$ci_ub), width = 0, linewidth = 2, colour = MF$ink) +
    ggplot2::geom_point(data = pooled, ggplot2::aes(x = .data$estimate), size = 4, shape = 21, fill = MF$white, colour = MF$ink, stroke = 1.4) +
    ggplot2::scale_colour_manual(values = DOMAIN_COLOURS, guide = "none") +
    ggplot2::scale_size_continuous(range = c(1, 4), guide = "none") +
    ggplot2::labs(
      title = "Pooled pre-post change by domain",
      subtitle = "Points: individual effect sizes (size = precision). Bar: 95% CI. Line: 95% prediction interval.",
      x = g_axis_label, y = NULL, caption = "Synthetic example data. Training arms only."
    ) +
    theme_mf()
}

# Individual effects by load category with model-implied means (orchard plot).
plot_load <- function(model) {
  d <- model$data
  pred <- predict_moderated(model, rep(model$sets_centre, 2), n = 1)
  set.seed(1)
  ggplot2::ggplot(d, ggplot2::aes(x = .data$yi, y = .data$load_category, colour = .data$load_category)) +
    ggplot2::geom_vline(xintercept = 0, colour = MF$muted, linewidth = 0.4) +
    ggplot2::geom_jitter(ggplot2::aes(size = 1 / sqrt(.data$vi)), height = 0.2, width = 0, alpha = 0.45, stroke = 0) +
    ggplot2::geom_errorbar(data = pred, ggplot2::aes(x = NULL, xmin = .data$ci_lb, xmax = .data$ci_ub), width = 0, linewidth = 2, colour = MF$ink) +
    ggplot2::geom_point(data = pred, ggplot2::aes(x = .data$estimate), size = 4, shape = 21, fill = MF$white, colour = MF$ink, stroke = 1.4) +
    ggplot2::scale_colour_manual(values = LOAD_COLOURS, guide = "none") +
    ggplot2::scale_size_continuous(range = c(1, 4), guide = "none") +
    ggplot2::labs(
      title = paste0(model$domain, ": effect of load"),
      subtitle = paste0("Model-implied mean and 95% CI at ", model$sets_centre, " weekly sets per exercise."),
      x = g_axis_label, y = NULL, caption = "Synthetic example data."
    ) +
    theme_mf()
}

# Dose-response: effect size against weekly sets per exercise, by load.
plot_sets <- function(model) {
  d <- model$data
  pred <- predict_moderated(model, range(d$sets_per_exercise_week))
  ggplot2::ggplot(d, ggplot2::aes(x = .data$sets_per_exercise_week, y = .data$yi, colour = .data$load_category)) +
    ggplot2::geom_hline(yintercept = 0, colour = MF$muted, linewidth = 0.4) +
    ggplot2::geom_ribbon(data = pred, ggplot2::aes(y = NULL, ymin = .data$ci_lb, ymax = .data$ci_ub, fill = .data$load_category), colour = NA, alpha = 0.10) +
    ggplot2::geom_point(ggplot2::aes(size = 1 / sqrt(.data$vi)), alpha = 0.55, stroke = 0, position = ggplot2::position_jitter(width = 0.15, height = 0, seed = 1)) +
    ggplot2::geom_line(data = pred, ggplot2::aes(y = .data$estimate), linewidth = 0.9) +
    ggplot2::scale_colour_manual(values = LOAD_COLOURS) +
    ggplot2::scale_fill_manual(values = LOAD_COLOURS, guide = "none") +
    ggplot2::scale_size_continuous(range = c(1, 4), guide = "none") +
    ggplot2::labs(
      title = paste0(model$domain, ": weekly sets per exercise"),
      subtitle = "Meta-regression line and 95% CI by load category.",
      x = "Weekly sets per exercise", y = g_axis_label, caption = "Synthetic example data. Points jittered horizontally."
    ) +
    theme_mf()
}

# ---- data visualiser -------------------------------------------------------------

VIZ_VIEWS <- tibble::tribble(
  ~view, ~label, ~group, ~by_domain, ~description,
  "effect_distribution", "Distribution of effects", "Effect sizes", TRUE, "Histogram of pre-post standardized mean changes.",
  "effect_vs_sets", "Effects vs. weekly sets", "Effect sizes", TRUE, "Effect size against weekly sets per exercise.",
  "effect_vs_weeks", "Effects vs. duration", "Effect sizes", TRUE, "Effect size against intervention length.",
  "effect_by_status", "Effects by training status", "Effect sizes", TRUE, "Effect sizes in untrained vs. trained samples.",
  "studies_by_year", "Studies by year", "Database", FALSE, "Number of studies by publication year.",
  "measures_by_domain", "Outcomes by domain", "Database", FALSE, "Number of outcome measures and effect sizes by domain.",
  "sample_characteristics", "Sample characteristics", "Participants", FALSE, "Arm-level participant characteristics."
)

ALL_DOMAINS <- "All domains"

# Every (view, domain) combination the visualiser can show.
make_viz_grid <- function(effect_sizes, min_effects = 10) {
  counts <- table(effect_sizes$domain[!effect_sizes$is_control])
  domains <- names(DOMAIN_COLOURS)[names(DOMAIN_COLOURS) %in% names(counts[counts >= min_effects])]
  rows <- lapply(seq_len(nrow(VIZ_VIEWS)), function(i) {
    v <- VIZ_VIEWS[i, ]
    ds <- if (v$by_domain) c(ALL_DOMAINS, domains) else ALL_DOMAINS
    tibble::tibble(view = v$view, domain = ds)
  })
  g <- dplyr::bind_rows(rows)
  g$id <- paste(g$view, slugify(g$domain), sep = "--")
  g
}

slugify <- function(x) gsub("(^-|-$)", "", gsub("[^a-z0-9]+", "-", tolower(x)))

viz_effects <- function(effect_sizes, domain) {
  d <- dplyr::filter(effect_sizes, !.data$is_control)
  if (domain != ALL_DOMAINS) d <- dplyr::filter(d, .data$domain == !!domain)
  d
}

build_viz_plot <- function(view, domain, hub, effect_sizes, arms) {
  subtitle_domain <- if (domain == ALL_DOMAINS) "All outcome domains" else domain
  caption <- "Synthetic example data. Training arms only; non-training controls excluded."
  if (domain %in% c(ALL_DOMAINS, "Body Composition")) caption <- paste(caption, "Fat-mass effects are negative when fat mass decreases.")
  by_domain_aes <- domain == ALL_DOMAINS

  switch(view,
    effect_distribution = {
      d <- viz_effects(effect_sizes, domain)
      p <- if (by_domain_aes) {
        ggplot2::ggplot(d, ggplot2::aes(x = .data$yi)) +
          ggplot2::geom_histogram(binwidth = 0.1, boundary = 0, fill = MF$blue, colour = MF$white, linewidth = 0.3) +
          ggplot2::facet_wrap(~ label_domain(domain), ncol = 2, scales = "free_y")
      } else {
        ggplot2::ggplot(d, ggplot2::aes(x = .data$yi, fill = .data$load_category)) +
          ggplot2::geom_histogram(binwidth = 0.1, boundary = 0, colour = MF$white, linewidth = 0.3) +
          ggplot2::scale_fill_manual(values = LOAD_COLOURS)
      }
      p + ggplot2::geom_vline(xintercept = 0, colour = MF$muted, linewidth = 0.4) +
        ggplot2::labs(title = "Distribution of effect sizes", subtitle = paste0(subtitle_domain, " · ", nrow(d), " effects"), x = g_axis_label, y = "Effect sizes", caption = caption)
    },
    effect_vs_sets = viz_scatter(viz_effects(effect_sizes, domain), "sets_per_exercise_week", "Weekly sets per exercise", "Effect size vs. weekly sets per exercise", subtitle_domain, caption, by_domain_aes, jitter = 0.15),
    effect_vs_weeks = viz_scatter(viz_effects(effect_sizes, domain), "intervention_weeks", "Intervention length (weeks)", "Effect size vs. intervention length", subtitle_domain, caption, by_domain_aes, jitter = 0.15),
    effect_by_status = {
      d <- viz_effects(effect_sizes, domain)
      ggplot2::ggplot(d, ggplot2::aes(x = .data$yi, y = .data$training_status, colour = .data$training_status)) +
        ggplot2::geom_vline(xintercept = 0, colour = MF$muted, linewidth = 0.4) +
        ggplot2::geom_point(ggplot2::aes(size = 1 / sqrt(.data$vi)), alpha = 0.45, stroke = 0, position = ggplot2::position_jitter(width = 0, height = 0.2, seed = 1)) +
        ggplot2::geom_boxplot(fill = NA, colour = MF$ink, outlier.shape = NA, width = 0.35, linewidth = 0.4) +
        ggplot2::scale_colour_manual(values = STATUS_COLOURS, guide = "none") +
        ggplot2::scale_size_continuous(range = c(1, 4), guide = "none") +
        ggplot2::labs(title = "Effect sizes by training status", subtitle = paste0(subtitle_domain, " · box: median and interquartile range"), x = g_axis_label, y = NULL, caption = caption)
    },
    studies_by_year = {
      ggplot2::ggplot(hub$study, ggplot2::aes(x = .data$year)) +
        ggplot2::geom_bar(fill = MF$blue, width = 0.8) +
        ggplot2::scale_y_continuous(breaks = function(l) seq(0, ceiling(l[2]), by = 1), expand = ggplot2::expansion(mult = c(0, 0.05))) +
        ggplot2::labs(title = "Studies by publication year", subtitle = paste(nrow(hub$study), "studies"), x = NULL, y = "Studies", caption = "Synthetic example data.")
    },
    measures_by_domain = {
      counts <- dplyr::bind_rows(
        dplyr::count(hub$measure, .data$domain) |> dplyr::mutate(what = "Outcome measures"),
        dplyr::count(dplyr::filter(effect_sizes, !.data$is_control), .data$domain) |> dplyr::mutate(what = "Effect sizes (training arms)")
      )
      counts$domain <- factor(counts$domain, levels = rev(names(sort(table(hub$measure$domain)))))
      ggplot2::ggplot(counts, ggplot2::aes(x = .data$n, y = .data$domain)) +
        ggplot2::geom_col(fill = MF$blue, width = 0.6) +
        ggplot2::geom_text(ggplot2::aes(label = .data$n), hjust = -0.2, colour = MF$ink, size = 3.2) +
        ggplot2::facet_wrap(~ what, scales = "free_x") +
        ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0, 0.18))) +
        ggplot2::labs(title = "Outcomes by domain", subtitle = "Measures recorded, and effect sizes derived from them", x = NULL, y = NULL, caption = "Synthetic example data.")
    },
    sample_characteristics = {
      long <- dplyr::bind_rows(
        tibble::tibble(var = "Age (years)", value = hub$arm$age_m),
        tibble::tibble(var = "Body mass (kg)", value = hub$arm$body_mass_m),
        tibble::tibble(var = "Training experience (years)", value = hub$arm$training_exp_m),
        tibble::tibble(var = "Proportion male", value = hub$arm$proportion_male),
        tibble::tibble(var = "Arm sample size (n)", value = as.numeric(hub$arm$n)),
        tibble::tibble(var = "Height (cm)", value = hub$arm$height_m)
      ) |> dplyr::filter(!is.na(.data$value))
      ggplot2::ggplot(long, ggplot2::aes(x = .data$value)) +
        ggplot2::geom_histogram(bins = 20, fill = MF$blue, colour = MF$white, linewidth = 0.3) +
        ggplot2::facet_wrap(~ var, scales = "free", ncol = 3) +
        ggplot2::labs(title = "Sample characteristics", subtitle = paste(nrow(hub$arm), "arms, reported arm-level means"), x = NULL, y = "Arms", caption = "Synthetic example data.")
    },
    stop("Unknown visualiser view: ", view, call. = FALSE)
  ) + theme_mf()
}

viz_scatter <- function(d, x, xlab, title, subtitle, caption, by_domain, jitter = 0) {
  d <- dplyr::filter(d, !is.na(.data[[x]]))
  p <- ggplot2::ggplot(d, ggplot2::aes(x = .data[[x]], y = .data$yi)) +
    ggplot2::geom_hline(yintercept = 0, colour = MF$muted, linewidth = 0.4)
  pos <- ggplot2::position_jitter(width = jitter, height = 0, seed = 1)
  p <- if (by_domain) {
    p + ggplot2::geom_point(ggplot2::aes(colour = .data$domain, shape = .data$domain), size = 2.2, alpha = 0.7, position = pos) +
      ggplot2::scale_colour_manual(values = DOMAIN_COLOURS, labels = label_domain) +
      ggplot2::scale_shape_manual(values = DOMAIN_SHAPES, labels = label_domain)
  } else {
    p + ggplot2::geom_point(ggplot2::aes(colour = .data$load_category, size = 1 / sqrt(.data$vi)), alpha = 0.6, stroke = 0, position = pos) +
      ggplot2::scale_colour_manual(values = LOAD_COLOURS) +
      ggplot2::scale_size_continuous(range = c(1, 4), guide = "none")
  }
  p + ggplot2::labs(title = title, subtitle = subtitle, x = xlab, y = g_axis_label, caption = paste(caption, if (jitter > 0) "Points jittered horizontally."))
}

viz_alt_text <- function(view, domain, effect_sizes, hub) {
  v <- VIZ_VIEWS[VIZ_VIEWS$view == view, ]
  n <- nrow(viz_effects(effect_sizes, domain))
  scope <- if (v$by_domain) paste0(" (", domain, ", ", n, " effect sizes)") else ""
  paste0(v$description, scope)
}

render_viz_plot <- function(viz_row, hub, effect_sizes, arms, out_dir) {
  plot <- build_viz_plot(viz_row$view, viz_row$domain, hub, effect_sizes, arms)
  height <- if (viz_row$view == "sample_characteristics" || (viz_row$view == "effect_distribution" && viz_row$domain == ALL_DOMAINS)) 5.5 else 4.5
  write_svg(plot, file.path(out_dir, paste0(viz_row$id, ".svg")), height = height)
}

write_viz_manifest <- function(viz_grid, viz_files, effect_sizes, hub, path) {
  plots <- lapply(seq_len(nrow(viz_grid)), function(i) {
    list(
      id = viz_grid$id[i], view = viz_grid$view[i], domain = viz_grid$domain[i],
      file = basename(viz_files[i]),
      alt = viz_alt_text(viz_grid$view[i], viz_grid$domain[i], effect_sizes, hub)
    )
  })
  views <- lapply(seq_len(nrow(VIZ_VIEWS)), function(i) {
    v <- VIZ_VIEWS[i, ]
    list(view = v$view, label = v$label, group = v$group, description = v$description,
         domains = I(unique(viz_grid$domain[viz_grid$view == v$view])))
  })
  manifest <- list(
    generated_by = "_targets.R (viz_manifest). Do not edit by hand.",
    views = views, plots = plots
  )
  write_lines_atomic(jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE), path)
  path
}
