# Reading and typing the hub tables.
#
# Tables are always read as character first so that validation sees exactly
# what is in the CSV (no silent type guessing), then cast to the types declared
# in config/schema.yml once validation has passed.

# Read config/project.yml and fail early, naming every missing or invalid
# setting, rather than partway through the pipeline.
read_project_config <- function(path = "config/project.yml") {
  if (!file.exists(path)) {
    stop("Project configuration not found: ", path, call. = FALSE)
  }
  cfg <- yaml::read_yaml(path)
  required <- c(
    "project.title", "project.repository", "project.site_url",
    "paths.schema", "paths.site_variables",
    "analysis.pre_post_r", "analysis.high_load_min_pct_1rm", "analysis.high_load_max_rm",
    "analysis.sets_centre", "analysis.meta_domains", "analysis.min_studies_per_model"
  )
  get <- function(key) Reduce(function(x, k) if (is.list(x)) x[[k]] else NULL, strsplit(key, ".", fixed = TRUE)[[1]], cfg)
  missing <- required[vapply(required, function(k) is.null(get(k)), logical(1))]
  problems <- if (length(missing)) paste0("missing setting(s): ", paste(missing, collapse = ", ")) else character()
  r <- get("analysis.pre_post_r")
  if (!is.null(r) && !(is.numeric(r) && length(r) == 1 && r > -1 && r < 1)) {
    problems <- c(problems, "analysis.pre_post_r must be a single number between -1 and 1")
  }
  if (length(problems)) {
    stop("Invalid ", path, ": ", paste(problems, collapse = "; "), ".", call. = FALSE)
  }
  cfg
}

read_schema <- function(path = "config/schema.yml") {
  if (!file.exists(path)) {
    stop("Schema file not found: ", path, call. = FALSE)
  }
  schema <- yaml::read_yaml(path)
  if (is.null(schema$tables) || length(schema$tables) == 0) {
    stop("Schema ", path, " declares no tables.", call. = FALSE)
  }
  schema
}

# Named vector of every data file the schema declares, relative to `root`.
hub_data_paths <- function(schema, root = ".") {
  files <- c(
    vapply(schema$tables, function(t) t$file, character(1)),
    vocabulary = schema$vocabulary_file
  )
  stats::setNames(file.path(root, files), names(files))
}

# Parse problems are captured eagerly into a plain data frame (attribute
# "parse_problems"), and readr's own attributes are dropped: they hold
# external pointers that do not survive serialization, e.g. when targets
# stores and reloads the table (readr::problems() then fails with bad_weak_ptr).
read_csv_character <- function(path) {
  # readr's own parse warning is muted: validate_table() reports the problems.
  df <- suppressWarnings(classes = "vroom_parse_issue", readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    na = "",
    trim_ws = FALSE,
    lazy = FALSE,
    progress = FALSE,
    show_col_types = FALSE,
    locale = readr::locale(encoding = "UTF-8")
  ))
  problems <- as.data.frame(readr::problems(df))
  df <- tibble::as_tibble(as.data.frame(df, stringsAsFactors = FALSE))
  attr(df, "parse_problems") <- problems
  df
}

parse_problems <- function(df) attr(df, "parse_problems") %||% data.frame(row = integer())

# Read every declared table as character. Missing files are recorded as NULL
# so that validation can report them rather than failing on the first one.
read_hub_raw <- function(schema, root = ".") {
  paths <- hub_data_paths(schema, root)
  read_one <- function(path) {
    if (!file.exists(path)) {
      return(NULL)
    }
    read_csv_character(path)
  }
  list(
    root = root,
    tables = lapply(paths[names(schema$tables)], read_one),
    vocabulary = read_one(paths[["vocabulary"]])
  )
}

# Cast validated character tables to their declared types.
cast_hub <- function(raw, schema) {
  out <- lapply(names(schema$tables), function(name) {
    spec <- schema$tables[[name]]$columns
    df <- raw$tables[[name]]
    for (col in names(spec)) {
      df[[col]] <- switch(
        spec[[col]]$type,
        integer = as.integer(df[[col]]),
        number = as.numeric(df[[col]]),
        string = df[[col]],
        stop("Unknown column type '", spec[[col]]$type, "' for ", name, ".", col, call. = FALSE)
      )
    }
    df[names(spec)]
  })
  stats::setNames(out, names(schema$tables))
}

# Read, validate and type the hub in one call. Fails with every problem listed
# if the data do not satisfy the schema.
load_hub <- function(schema_path = "config/schema.yml", root = ".") {
  schema <- read_schema(file.path(root, schema_path))
  raw <- read_hub_raw(schema, root)
  assert_valid_hub(validate_hub(raw, schema))
  cast_hub(raw, schema)
}
