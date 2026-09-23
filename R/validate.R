# Data validation: the checks a relational database would enforce for free.
#
# validate_hub() returns one row per problem found (an empty data frame when the
# data are valid). assert_valid_hub() turns that into a single, readable error.
# Row references are CSV line numbers (the header is line 1), so a contributor
# can go straight to the offending line.

validate_hub <- function(raw, schema) {
  issues <- list(validate_schema_definition(schema, raw$vocabulary))
  issues <- c(issues, list(check_undeclared_files(schema, raw$root)))

  vocab <- raw$vocabulary
  for (name in names(schema$tables)) {
    issues <- c(issues, list(validate_table(name, raw$tables[[name]], schema$tables[[name]], vocab)))
  }
  for (name in names(schema$tables)) {
    issues <- c(issues, list(validate_relations(name, raw$tables, schema)))
  }
  do.call(rbind, c(list(empty_issues()), issues))
}

assert_valid_hub <- function(issues) {
  if (nrow(issues) > 0) {
    stop(
      "Hub data failed validation with ", nrow(issues), " problem(s):\n",
      paste0("  - ", format_issues(issues), collapse = "\n"),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

format_issues <- function(issues) {
  where <- ifelse(is.na(issues$column), issues$table, paste0(issues$table, ".", issues$column))
  paste0("[", issues$check, "] ", where, ": ", issues$message)
}

# ---- issue helpers -----------------------------------------------------------

empty_issues <- function() {
  data.frame(
    table = character(), check = character(), column = character(),
    n_rows = integer(), message = character(), stringsAsFactors = FALSE
  )
}

issue <- function(table, check, message, column = NA_character_, n_rows = NA_integer_) {
  data.frame(
    table = table, check = check, column = column, n_rows = as.integer(n_rows),
    message = message, stringsAsFactors = FALSE
  )
}

# Describe offending rows by CSV line number, showing at most a few examples.
describe_rows <- function(rows, values = NULL, max_examples = 5) {
  lines <- rows + 1L
  shown <- utils::head(seq_along(lines), max_examples)
  examples <- if (is.null(values)) {
    as.character(lines[shown])
  } else {
    paste0(lines[shown], " (\"", values[shown], "\")")
  }
  more <- if (length(lines) > max_examples) paste0(", and ", length(lines) - max_examples, " more") else ""
  paste0(length(lines), " row(s), line(s) ", paste(examples, collapse = ", "), more)
}

is_missing <- function(x) is.na(x) | x == ""

# ---- schema and file-level checks --------------------------------------------

validate_schema_definition <- function(schema, vocabulary) {
  out <- list(empty_issues())
  if (is.null(vocabulary)) {
    return(issue("vocabulary", "missing_file", paste0("Vocabulary file not found: ", schema$vocabulary_file)))
  }
  if (!identical(names(vocabulary), c("vocabulary", "value", "description"))) {
    out <- c(out, list(issue("vocabulary", "columns", "Expected columns: vocabulary, value, description.")))
    return(do.call(rbind, out))
  }
  dup <- which(duplicated(vocabulary[c("vocabulary", "value")]))
  if (length(dup)) {
    out <- c(out, list(issue("vocabulary", "duplicate_key", paste("Duplicate (vocabulary, value):", describe_rows(dup, vocabulary$value[dup])), n_rows = length(dup))))
  }
  known_vocab <- unique(vocabulary$vocabulary)
  for (tname in names(schema$tables)) {
    t <- schema$tables[[tname]]
    cols <- names(t$columns)
    referenced <- c(
      t$primary_key,
      unlist(lapply(t$foreign_keys, `[[`, "columns")),
      unlist(lapply(t$checks, function(ch) c(ch$column, ch$parent, ch$lower, ch$upper, ch$left$column, ch$right$column)))
    )
    unknown <- setdiff(referenced, cols)
    if (length(unknown)) {
      out <- c(out, list(issue(tname, "schema", paste("Keys/checks reference undeclared column(s):", paste(unknown, collapse = ", ")))))
    }
    for (fk in t$foreign_keys) {
      if (!fk$references %in% names(schema$tables)) {
        out <- c(out, list(issue(tname, "schema", paste("Foreign key references unknown table:", fk$references))))
      }
    }
    for (col in cols) {
      v <- c(t$columns[[col]][["vocab"]], t$columns[[col]][["vocab_list"]])
      if (length(v) && !v %in% known_vocab) {
        out <- c(out, list(issue(tname, "schema", paste0("Vocabulary '", v, "' is not defined in ", schema$vocabulary_file, "."), column = col)))
      }
    }
  }
  do.call(rbind, out)
}

check_undeclared_files <- function(schema, root) {
  declared <- normalizePath(hub_data_paths(schema, root), winslash = "/", mustWork = FALSE)
  present <- normalizePath(list.files(file.path(root, "data"), pattern = "\\.csv$", recursive = TRUE, full.names = TRUE), winslash = "/")
  extra <- setdiff(present, declared)
  if (!length(extra)) {
    return(empty_issues())
  }
  issue("data/", "undeclared_file", paste0(
    "CSV file(s) not declared in config/schema.yml: ",
    paste(sub(paste0("^", normalizePath(root, winslash = "/"), "/"), "", extra), collapse = ", ")
  ))
}

# ---- single-table checks -----------------------------------------------------

validate_table <- function(name, df, spec, vocabulary) {
  if (is.null(df)) {
    return(issue(name, "missing_file", paste0("Table file not found: ", spec$file)))
  }
  out <- list(empty_issues())

  probs <- parse_problems(df)
  if (nrow(probs)) {
    out <- c(out, list(issue(name, "parse", paste("CSV could not be parsed cleanly:", describe_rows(probs$row - 1L)), n_rows = nrow(probs))))
  }

  expected <- names(spec$columns)
  missing_cols <- setdiff(expected, names(df))
  extra_cols <- setdiff(names(df), expected)
  if (length(missing_cols)) {
    out <- c(out, list(issue(name, "columns", paste("Missing column(s):", paste(missing_cols, collapse = ", ")))))
  }
  if (length(extra_cols)) {
    out <- c(out, list(issue(name, "columns", paste("Undeclared column(s):", paste(extra_cols, collapse = ", ")))))
  }

  for (col in intersect(expected, names(df))) {
    out <- c(out, list(validate_column(name, col, df[[col]], spec$columns[[col]], vocabulary)))
  }

  pk <- spec$primary_key
  if (length(pk) && all(pk %in% names(df))) {
    key_missing <- which(Reduce(`|`, lapply(df[pk], is_missing)))
    if (length(key_missing)) {
      out <- c(out, list(issue(name, "primary_key", paste("Missing primary-key value:", describe_rows(key_missing)), paste(pk, collapse = ", "), length(key_missing))))
    }
    dup <- which(duplicated(df[pk]))
    if (length(dup)) {
      keys <- do.call(paste, c(df[dup, pk], sep = " / "))
      out <- c(out, list(issue(name, "duplicate_key", paste("Duplicate primary key:", describe_rows(dup, keys)), paste(pk, collapse = ", "), length(dup))))
    }
  }
  do.call(rbind, out)
}

validate_column <- function(table, col, x, spec, vocabulary) {
  out <- list(empty_issues())
  add <- function(check, rows, values = NULL, what) {
    out[[length(out) + 1]] <<- issue(table, check, paste0(what, ": ", describe_rows(rows, values)), col, length(rows))
  }
  present <- !is_missing(x)

  if (isTRUE(spec$required)) {
    rows <- which(!present)
    if (length(rows)) add("required", rows, what = "Missing required value")
  }

  rows <- which(present & x != trimws(x))
  if (length(rows)) add("whitespace", rows, x[rows], "Leading or trailing whitespace")

  numeric_ok <- present
  if (spec$type %in% c("integer", "number")) {
    pattern <- if (spec$type == "integer") "^-?[0-9]+$" else "^-?([0-9]+\\.?[0-9]*|\\.[0-9]+)([eE][-+]?[0-9]+)?$"
    bad <- present & !grepl(pattern, x)
    rows <- which(bad)
    if (length(rows)) add("type", rows, x[rows], paste("Not a valid", spec$type))
    numeric_ok <- present & !bad
    values <- suppressWarnings(as.numeric(x))
    if (!is.null(spec$min)) {
      rows <- which(numeric_ok & values < spec$min)
      if (length(rows)) add("range", rows, x[rows], paste("Below minimum", spec$min))
    }
    if (!is.null(spec$max)) {
      rows <- which(numeric_ok & values > spec$max)
      if (length(rows)) add("range", rows, x[rows], paste("Above maximum", spec$max))
    }
  }

  if (!is.null(spec$pattern)) {
    rows <- which(present & !grepl(spec$pattern, x, perl = TRUE))
    if (length(rows)) add("pattern", rows, x[rows], paste0("Does not match pattern ", spec$pattern))
  }

  if (!is.null(spec[["vocab"]]) && !is.null(vocabulary)) {
    allowed <- vocabulary$value[vocabulary$vocabulary == spec[["vocab"]]]
    rows <- which(present & !x %in% allowed)
    if (length(rows)) add("vocab", rows, x[rows], paste0("Value not in vocabulary '", spec[["vocab"]], "'"))
  }

  if (!is.null(spec[["vocab_list"]]) && !is.null(vocabulary)) {
    allowed <- vocabulary$value[vocabulary$vocabulary == spec[["vocab_list"]]]
    ok <- vapply(strsplit(x, ",", fixed = TRUE), function(parts) all(parts %in% allowed), logical(1))
    rows <- which(present & !ok)
    if (length(rows)) add("vocab", rows, x[rows], paste0("Contains a value not in vocabulary '", spec[["vocab_list"]], "' (comma-separated, no spaces)"))
  }

  do.call(rbind, out)
}

# ---- cross-table and row-level rule checks -----------------------------------

key_string <- function(df, cols) do.call(paste, c(unname(as.list(df[cols])), sep = "\x1f"))

validate_relations <- function(name, tables, schema) {
  spec <- schema$tables[[name]]
  df <- tables[[name]]
  if (is.null(df)) {
    return(empty_issues())
  }
  out <- list(empty_issues())
  has <- function(d, cols) !is.null(d) && all(cols %in% names(d))

  for (fk in spec$foreign_keys) {
    parent <- tables[[fk$references]]
    if (!has(df, fk$columns) || !has(parent, fk$ref_columns)) next
    complete <- !Reduce(`|`, lapply(df[fk$columns], is_missing))
    unresolved <- which(complete & !key_string(df, fk$columns) %in% key_string(parent, fk$ref_columns))
    if (length(unresolved)) {
      keys <- do.call(paste, c(df[unresolved, fk$columns], sep = " / "))
      out <- c(out, list(issue(
        name, "foreign_key",
        paste0("No matching row in ", fk$references, " (", paste(fk$ref_columns, collapse = ", "), "): ", describe_rows(unresolved, keys)),
        paste(fk$columns, collapse = ", "), length(unresolved)
      )))
    }
  }

  for (ch in spec$checks) {
    out <- c(out, list(switch(
      ch$type,
      ordered = check_ordered(name, df, ch),
      id_prefix = check_id_prefix(name, df, ch),
      same_parent = check_same_parent(name, df, tables, ch),
      issue(name, "schema", paste("Unknown check type:", ch$type))
    )))
  }
  do.call(rbind, out)
}

check_ordered <- function(name, df, ch) {
  if (!all(c(ch$lower, ch$upper) %in% names(df))) {
    return(empty_issues())
  }
  lo <- suppressWarnings(as.numeric(df[[ch$lower]]))
  hi <- suppressWarnings(as.numeric(df[[ch$upper]]))
  bad <- if (isTRUE(ch$strict)) lo >= hi else lo > hi
  rows <- which(!is.na(bad) & bad)
  if (!length(rows)) {
    return(empty_issues())
  }
  op <- if (isTRUE(ch$strict)) "<" else "<="
  issue(name, "ordered", paste0("Expected ", ch$lower, " ", op, " ", ch$upper, ": ",
    describe_rows(rows, paste(df[[ch$lower]][rows], df[[ch$upper]][rows], sep = " vs "))),
    paste(ch$lower, ch$upper, sep = ", "), length(rows))
}

check_id_prefix <- function(name, df, ch) {
  if (!all(c(ch$column, ch$parent) %in% names(df))) {
    return(empty_issues())
  }
  expected <- paste0(df[[ch$parent]], ch$separator)
  rows <- which(!is_missing(df[[ch$column]]) & !startsWith(df[[ch$column]], expected))
  if (!length(rows)) {
    return(empty_issues())
  }
  issue(name, "id_prefix", paste0(ch$column, " must start with ", ch$parent, " + \"", ch$separator, "\": ",
    describe_rows(rows, df[[ch$column]][rows])), ch$column, length(rows))
}

# Two foreign keys in one row must point at rows that share the same parent,
# e.g. an outcome's arm and measure must both belong to the same study.
check_same_parent <- function(name, df, tables, ch) {
  lookup <- function(side) {
    ref <- tables[[side$table]]
    if (is.null(ref) || !all(c(side$key, side$value) %in% names(ref)) || !side$column %in% names(df)) {
      return(NULL)
    }
    ref[[side$value]][match(df[[side$column]], ref[[side$key]])]
  }
  left <- lookup(ch$left)
  right <- lookup(ch$right)
  if (is.null(left) || is.null(right)) {
    return(empty_issues())
  }
  rows <- which(!is.na(left) & !is.na(right) & left != right)
  if (!length(rows)) {
    return(empty_issues())
  }
  issue(name, "same_parent", paste0(ch$left$column, " and ", ch$right$column, " belong to different ", ch$left$value, " values: ",
    describe_rows(rows, paste(df[[ch$left$column]][rows], df[[ch$right$column]][rows], sep = " vs "))),
    paste(ch$left$column, ch$right$column, sep = ", "), length(rows))
}
