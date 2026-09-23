# Validate every table in data/ against config/schema.yml.
# Exits non-zero, listing every problem, if validation fails. Used by CI and
# safe to run locally at any time (it only reads files):
#
#   Rscript scripts/validate_data.R

source("R/hub_data.R")
source("R/validate.R")

schema <- read_schema("config/schema.yml")
raw <- read_hub_raw(schema)
issues <- validate_hub(raw, schema)

rows <- vapply(raw$tables, function(t) if (is.null(t)) NA_integer_ else nrow(t), integer(1))
message(paste(sprintf("  %-14s %7s rows", names(rows), format(rows, big.mark = ",")), collapse = "\n"))

if (nrow(issues) > 0) {
  message("\nValidation FAILED with ", nrow(issues), " problem(s):")
  message(paste0("  - ", format_issues(issues), collapse = "\n"))
  if (nzchar(Sys.getenv("GITHUB_ACTIONS"))) {
    # Surface each problem as an annotation on the pull request.
    for (i in seq_len(nrow(issues))) {
      file <- if (issues$table[i] %in% names(schema$tables)) schema$tables[[issues$table[i]]]$file else "config/schema.yml"
      cat(sprintf("::error file=%s,title=%s::%s\n", file, issues$check[i], gsub("\n", " ", format_issues(issues[i, ]))))
    }
  }
  quit(status = 1)
}
message("\nValidation passed: all tables satisfy config/schema.yml.")
