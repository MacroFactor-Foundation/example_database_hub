# Shared test setup: source the project's functions and provide fixtures.
# Run the suite from the project root with:
#   Rscript tests/testthat.R

options(warnPartialMatchDollar = TRUE)

project_root <- here::here()
for (f in list.files(file.path(project_root, "R"), pattern = "\\.R$", full.names = TRUE)) {
  source(f, local = FALSE)
}

schema_path <- file.path(project_root, "config", "schema.yml")

# A disposable copy of the real hub (data/ + config/) that tests can corrupt.
copy_hub <- function() {
  dir <- tempfile("hub-")
  dir.create(dir)
  file.copy(file.path(project_root, c("data", "config")), dir, recursive = TRUE)
  dir
}

# Edit one table of a copied hub, then return the validation issues.
issues_after <- function(table, edit) {
  root <- copy_hub()
  on.exit(unlink(root, recursive = TRUE))
  schema <- read_schema(file.path(root, "config", "schema.yml"))
  path <- file.path(root, schema$tables[[table]]$file)
  df <- read_csv_character(path)
  df <- edit(df)
  readr::write_csv(df, path, na = "")
  validate_hub(read_hub_raw(schema, root), schema)
}

test_analysis_config <- list(
  pre_post_r = 0.8, high_load_min_pct_1rm = 60, high_load_max_rm = 15,
  sets_centre = 6, min_studies_per_model = 5
)
