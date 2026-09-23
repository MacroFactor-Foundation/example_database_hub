# Pipeline for the hub's own example analyses and site interface.
#
# Run locally with:   targets::tar_make()
# Then render with:   quarto render site
#
# Outputs are written to site/generated/ and site/_variables.yml, which are
# committed so the site renders from a fresh clone without _targets/.

library(targets)

tar_option_set(
  packages = c("dplyr", "ggplot2", "metafor", "tibble"),
  format = "rds",
  seed = 20260923
)

tar_source("R")

gen <- function(...) file.path("site", "generated", ...)

list(
  # ---- inputs (tracked as files so edits to data or config trigger reruns) ----
  tar_target(project_file, "config/project.yml", format = "file"),
  tar_target(project, read_project_config(project_file)),
  tar_target(schema_file, project$paths$schema, format = "file"),
  tar_target(schema, read_schema(schema_file)),
  tar_target(data_files, hub_data_paths(schema), format = "file"),

  # ---- validated, typed hub tables ---------------------------------------------
  tar_target(hub_raw, {
    data_files
    read_hub_raw(schema)
  }),
  tar_target(validation, assert_valid_hub(validate_hub(hub_raw, schema))),
  tar_target(hub, {
    validation
    cast_hub(hub_raw, schema)
  }),

  # ---- analyses ------------------------------------------------------------------
  tar_target(arms, summarise_arms(hub, project$analysis)),
  tar_target(effect_sizes, compute_effect_sizes(hub, arms, project$analysis)),
  tar_target(meta_domains, project$analysis$meta_domains),
  tar_target(
    domain_models,
    fit_domain_models(effect_sizes, meta_domains, project$analysis),
    pattern = map(meta_domains),
    iteration = "list"
  ),
  tar_target(pooled, summarise_pooled(domain_models)),
  tar_target(moderators, summarise_moderators(domain_models)),

  # ---- analysis figures ----------------------------------------------------------
  tar_target(fig_pooled, write_svg(plot_pooled(effect_sizes, pooled), gen("figures", "pooled-by-domain.svg")), format = "file"),
  tar_target(
    fig_load,
    write_svg(plot_load(domain_models), gen("figures", paste0("load-", slugify(domain_models$domain), ".svg"))),
    pattern = map(domain_models),
    format = "file"
  ),
  tar_target(
    fig_sets,
    write_svg(plot_sets(domain_models), gen("figures", paste0("sets-", slugify(domain_models$domain), ".svg"))),
    pattern = map(domain_models),
    format = "file"
  ),

  # ---- data visualiser (one static SVG per view x domain, plus a manifest) --------
  tar_target(viz_grid, make_viz_grid(effect_sizes)),
  tar_target(
    viz_plots,
    render_viz_plot(viz_grid, hub, effect_sizes, arms, gen("viz")),
    pattern = map(viz_grid),
    format = "file"
  ),
  tar_target(viz_manifest, write_viz_manifest(viz_grid, viz_plots, effect_sizes, hub, gen("viz", "manifest.json")), format = "file"),

  # ---- tables and scalar values for the site ---------------------------------------
  tar_target(tbl_table_counts, write_table_counts(hub, schema, gen("tables", "table-counts.md")), format = "file"),
  tar_target(tbl_study_characteristics, write_study_characteristics(hub, gen("tables", "study-characteristics.md")), format = "file"),
  tar_target(tbl_pooled, write_pooled_table(pooled, gen("tables", "pooled.md")), format = "file"),
  tar_target(tbl_moderators, write_moderator_table(moderators, gen("tables", "moderators.md")), format = "file"),
  tar_target(tbl_data_dictionary, write_data_dictionary(schema, hub_raw$vocabulary, gen("tables", "data-dictionary.md")), format = "file"),
  tar_target(
    site_variables,
    write_site_variables(hub, effect_sizes, pooled, moderators, project, project$paths$site_variables),
    format = "file"
  )
)
