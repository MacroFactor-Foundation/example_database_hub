test_that("data/README.md is up to date with config/schema.yml", {
  expected <- build_data_readme(read_schema(schema_path), read_csv_character(file.path(project_root, "data", "manual", "vocabulary.csv")))
  actual <- readLines(file.path(project_root, "data", "README.md"), encoding = "UTF-8")
  expect_identical(
    actual, expected,
    info = "Regenerate with: Rscript scripts/build_data_dictionary.R"
  )
})

test_that("the dictionary documents every table and column", {
  schema <- read_schema(schema_path)
  vocab <- read_csv_character(file.path(project_root, "data", "manual", "vocabulary.csv"))
  md <- paste(render_data_dictionary(schema, vocab), collapse = "\n")
  for (t in names(schema$tables)) {
    expect_match(md, paste0("`", t, "`"), fixed = TRUE)
    for (col in names(schema$tables[[t]]$columns)) {
      expect_match(md, paste0("`", col, "`"), fixed = TRUE)
    }
  }
})
