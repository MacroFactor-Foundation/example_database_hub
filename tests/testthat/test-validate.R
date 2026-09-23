test_that("the committed hub data pass validation", {
  schema <- read_schema(schema_path)
  issues <- validate_hub(read_hub_raw(schema, project_root), schema)
  expect_equal(nrow(issues), 0, info = paste(format_issues(issues), collapse = "\n"))
})

test_that("duplicate primary keys are reported with line numbers", {
  issues <- issues_after("study", function(df) rbind(df, df[3, ]))
  hit <- issues[issues$check == "duplicate_key" & issues$table == "study", ]
  expect_equal(nrow(hit), 1)
  expect_match(hit$message, "line\\(s\\) 52")
})

test_that("composite primary keys are checked", {
  issues <- issues_after("arm_week", function(df) rbind(df, df[1, ]))
  expect_true(any(issues$check == "duplicate_key" & issues$table == "arm_week"))
})

test_that("unresolved foreign keys are reported", {
  issues <- issues_after("arm", function(df) {
    df$study_id[1] <- "nobody2020a"
    df
  })
  hit <- issues[issues$check == "foreign_key" & issues$table == "arm", ]
  expect_equal(nrow(hit), 1)
  expect_match(hit$message, "nobody2020a")
})

test_that("composite foreign keys (arm, week) are checked", {
  issues <- issues_after("outcome", function(df) {
    df$week[1] <- "99"
    df
  })
  expect_true(any(issues$check == "foreign_key" & issues$table == "outcome"))
})

test_that("missing and undeclared columns are reported", {
  issues <- issues_after("measure", function(df) {
    df$domain <- NULL
    df$surprise <- "x"
    df
  })
  msgs <- issues$message[issues$check == "columns" & issues$table == "measure"]
  expect_true(any(grepl("Missing column\\(s\\): domain", msgs)))
  expect_true(any(grepl("Undeclared column\\(s\\): surprise", msgs)))
})

test_that("type, range, vocabulary and whitespace problems are reported", {
  issues <- issues_after("arm", function(df) {
    df$n[1] <- "twelve"
    df$proportion_male[2] <- "1.5"
    df$used_bfr[3] <- "yes"
    df$arm_label[4] <- " HL"
    df
  })
  checks <- issues$check[issues$table == "arm"]
  expect_setequal(checks, c("type", "range", "vocab", "whitespace"))
})

test_that("comma-separated vocabulary lists are checked element by element", {
  issues <- issues_after("measure", function(df) {
    i <- which(!is.na(df$muscle_assessed))[1]
    df$muscle_assessed[i] <- "RF,XYZ"
    df
  })
  expect_true(any(issues$check == "vocab" & issues$column == "muscle_assessed"))
})

test_that("a literal 'NA' string is not treated as missing", {
  issues <- issues_after("arm", function(df) {
    df$progression[1] <- "NA"
    df
  })
  expect_true(any(issues$check == "vocab" & issues$column == "progression"))
})

test_that("ordered-pair, id-prefix and same-parent rules are enforced", {
  ord <- issues_after("training_set", function(df) {
    df$reps_min[1] <- "40"
    df
  })
  expect_true(any(ord$check == "ordered"))

  pre <- issues_after("arm", function(df) {
    df$arm_id[1] <- "wrongstudy2000a_hl"
    df
  })
  expect_true(any(pre$check == "id_prefix"))

  same <- issues_after("outcome", function(df) {
    other <- df$measure_id[df$measure_id != df$measure_id[1] & !startsWith(df$measure_id, sub("_m.*$", "", df$measure_id[1]))][1]
    df$measure_id[1] <- other
    df
  })
  expect_true(any(same$check == "same_parent"))
})

test_that("validation works on tables that were serialized and reloaded (as targets does)", {
  schema <- read_schema(schema_path)
  f <- tempfile(fileext = ".rds")
  saveRDS(read_hub_raw(schema, project_root), f)
  raw <- readRDS(f)
  expect_equal(nrow(validate_hub(raw, schema)), 0)
})

test_that("malformed CSV rows are reported as parse problems", {
  root <- copy_hub()
  on.exit(unlink(root, recursive = TRUE))
  path <- file.path(root, "data", "reliability.csv")
  lines <- readLines(path)
  lines[3] <- paste0(lines[3], ",extra-field")
  writeLines(lines, path)
  schema <- read_schema(file.path(root, "config", "schema.yml"))
  issues <- validate_hub(read_hub_raw(schema, root), schema)
  hit <- issues[issues$check == "parse", ]
  expect_equal(nrow(hit), 1)
  expect_match(hit$message, "line\\(s\\) 3\\b")
})

test_that("undeclared CSV files in data/ are reported", {
  root <- copy_hub()
  on.exit(unlink(root, recursive = TRUE))
  writeLines("a,b", file.path(root, "data", "stray.csv"))
  schema <- read_schema(file.path(root, "config", "schema.yml"))
  issues <- validate_hub(read_hub_raw(schema, root), schema)
  expect_true(any(issues$check == "undeclared_file"))
})

test_that("assert_valid_hub() fails with every problem listed", {
  issues <- rbind(
    issue("study", "required", "Missing required value: 1 row(s), line(s) 2", "title", 1),
    issue("arm", "foreign_key", "No matching row", "study_id", 1)
  )
  expect_error(assert_valid_hub(issues), "2 problem\\(s\\)")
  expect_true(assert_valid_hub(empty_issues()))
})

test_that("project configuration is validated with actionable errors", {
  cfg <- read_project_config(file.path(project_root, "config", "project.yml"))
  expect_equal(cfg$analysis$meta_domains, c("Hypertrophy", "Strength"))

  bad <- tempfile(fileext = ".yml")
  cfg$analysis$pre_post_r <- 1.5
  cfg$analysis$sets_centre <- NULL
  yaml::write_yaml(cfg, bad)
  expect_error(read_project_config(bad), "analysis.sets_centre")
  expect_error(read_project_config(bad), "pre_post_r must be")
})

test_that("every schema column declares a known type and a description", {
  schema <- read_schema(schema_path)
  for (t in names(schema$tables)) {
    for (col in names(schema$tables[[t]]$columns)) {
      spec <- schema$tables[[t]]$columns[[col]]
      expect_true(spec$type %in% c("string", "integer", "number"), info = paste(t, col))
      expect_true(nzchar(spec$description %||% ""), info = paste(t, col))
    }
  }
})
