test_that("release assets bundle the data with matching checksums", {
  out <- tempfile("release-")
  on.exit(unlink(out, recursive = TRUE))
  paths <- build_release_assets(
    tag = "data-v0.0.0", commit = strrep("0", 40), out_dir = out,
    root = project_root, repository = "https://github.com/example/example_database_hub",
    build_date = as.Date("2026-01-01")
  )
  expect_true(all(file.exists(paths)))

  manifest <- jsonlite::read_json(paths[["manifest"]])
  expect_equal(manifest$tag, "data-v0.0.0")
  expect_equal(length(manifest$tables), length(read_schema(schema_path)$tables))
  study <- manifest$tables[[which(vapply(manifest$tables, `[[`, "", "table") == "study")]]
  expect_equal(study$sha256, unname(tools::sha256sum(file.path(project_root, "data", "study.csv"))))
  expect_equal(study$rows, 50)

  sums <- readLines(paths[["sums"]])
  expect_true(any(grepl("  data/training_set.csv$", sums)))
  expect_true(any(grepl("-data-v0.0.0-data.zip$", sums)))

  listed <- zip::zip_list(paths[["bundle"]])$filename
  expect_true(all(c("data/study.csv", "data/manual/vocabulary.csv", "config/schema.yml", "LICENSE-DATA.md") %in% listed))
})

test_that("release tags must follow the data-vMAJOR.MINOR.PATCH scheme", {
  expect_error(build_release_assets("v1", "x", tempfile(), project_root, "r"), "data-vMAJOR")
})
