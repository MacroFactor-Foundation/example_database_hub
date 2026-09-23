hub <- load_hub(root = project_root)
arms <- summarise_arms(hub, test_analysis_config)
es <- compute_effect_sizes(hub, arms, test_analysis_config)

test_that("arm summaries cover every arm and classify training arms", {
  expect_equal(nrow(arms), nrow(hub$arm))
  training <- arms[!arms$is_control, ]
  expect_false(anyNA(training$load_category))
  expect_true(all(training$weekly_sets > 0))
  expect_true(all(is.na(arms$weekly_sets[arms$is_control])))
})

test_that("effect sizes match a hand calculation", {
  row <- es[1, ]
  pre <- hub$outcome[hub$outcome$arm_id == row$arm_id & hub$outcome$measure_id == row$measure_id & hub$outcome$week == 0, ]
  post <- hub$outcome[hub$outcome$arm_id == row$arm_id & hub$outcome$measure_id == row$measure_id, ]
  post <- post[which.max(post$week), ]
  sd_pre <- dplyr::coalesce(pre$sd, pre$se * sqrt(pre$n))
  n <- min(pre$n, post$n)
  j <- 1 - 3 / (4 * (n - 1) - 1)
  expect_equal(row$yi, j * (post$mean - pre$mean) / sd_pre, tolerance = 1e-3)
})

test_that("effect sizes have one row per arm x measure and finite variances", {
  expect_false(anyDuplicated(es$es_id) > 0)
  expect_true(all(is.finite(es$yi) & es$vi > 0))
  expect_true(all(es$domain %in% hub$measure$domain))
})

test_that("domain models fit and summarise", {
  m <- fit_domain_models(es, "Strength", test_analysis_config)
  pooled <- summarise_pooled(list(m))
  mods <- summarise_moderators(list(m))
  expect_equal(pooled$k, sum(es$domain == "Strength" & !es$is_control))
  expect_true(pooled$ci_lb < pooled$estimate && pooled$estimate < pooled$ci_ub)
  expect_setequal(mods$term, c("Intercept", "Low vs. high load", "Per additional weekly set per exercise"))
  expect_error(fit_domain_models(es[0, ], "Strength", test_analysis_config), "Too few studies")
})

test_that("figures and site files are written with brand fonts and warnings", {
  out <- tempfile("site-")
  m <- fit_domain_models(es, "Hypertrophy", test_analysis_config)
  svg <- write_svg(plot_sets(m), file.path(out, "sets.svg"))
  lines <- readLines(svg, warn = FALSE)
  expect_true(any(grepl("DM Sans", lines, fixed = TRUE)))
  expect_false(any(grepl("textLength", lines, fixed = TRUE)))
  expect_no_error(xml2::read_xml(svg))

  grid <- make_viz_grid(es)
  expect_false(anyDuplicated(grid$id) > 0)
  files <- vapply(seq_len(nrow(grid)), function(i) render_viz_plot(grid[i, ], hub, es, arms, out), character(1))
  expect_true(all(file.exists(files)))
  for (f in files) expect_no_error(xml2::read_xml(f), message = basename(f))
  manifest <- jsonlite::read_json(write_viz_manifest(grid, files, es, hub, file.path(out, "manifest.json")))
  expect_equal(length(manifest$plots), nrow(grid))

  md <- readLines(write_pooled_table(summarise_pooled(list(m)), file.path(out, "pooled.md")))
  expect_match(md[1], "Do not edit by hand", fixed = TRUE)
  unlink(out, recursive = TRUE)
})
