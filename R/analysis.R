# Example analyses run against the hub's own tables.
#
# 1. Arm-level training summaries (dose, load, proximity to failure).
# 2. Pre-post standardized mean changes per arm x measure.
# 3. Per-domain multilevel meta-analysis, and a meta-regression on load and
#    weekly sets per exercise.
#
# NOTE: the hub's current data are synthetic toy data, so these results
# illustrate the workflow only and say nothing about real training effects.

INTERVENTION_WEEK_TYPES <- c("Training", "Reduced Training", "Non-Training Control")

# One row per arm, with the training variables used as moderators.
summarise_arms <- function(hub, analysis) {
  intervention_weeks <- hub$arm_week |>
    dplyr::filter(.data$training_week_type %in% INTERVENTION_WEEK_TYPES) |>
    dplyr::count(.data$arm_id, name = "intervention_weeks")

  sets <- hub$training_set |>
    dplyr::semi_join(
      dplyr::filter(hub$arm_week, .data$training_week_type %in% INTERVENTION_WEEK_TYPES),
      by = c("arm_id", "week")
    ) |>
    dplyr::mutate(
      high_load = dplyr::case_when(
        .data$relative_load_type == "%1RM" ~ (.data$relative_load_min + .data$relative_load_max) / 2 >= analysis$high_load_min_pct_1rm,
        .data$relative_load_type == "RM" ~ (.data$rm_min + .data$rm_max) / 2 <= analysis$high_load_max_rm,
        TRUE ~ NA
      ),
      to_failure = .data$ptf_type == "FAIL"
    ) |>
    dplyr::group_by(.data$arm_id) |>
    dplyr::summarise(
      n_sets = dplyr::n(),
      n_exercises = dplyr::n_distinct(.data$exercise),
      n_sessions = dplyr::n_distinct(.data$week, .data$session),
      high_load_share = mean(.data$high_load, na.rm = TRUE),
      failure_share = mean(.data$to_failure, na.rm = TRUE),
      .groups = "drop"
    )

  hub$arm |>
    dplyr::select("arm_id", "study_id", "arm_label", "is_nontraining_control_group", "n", "training_exp_m") |>
    dplyr::left_join(intervention_weeks, by = "arm_id") |>
    dplyr::left_join(sets, by = "arm_id") |>
    dplyr::mutate(
      is_control = .data$is_nontraining_control_group == "Yes",
      weekly_sets = .data$n_sets / .data$intervention_weeks,
      sets_per_exercise_week = .data$weekly_sets / .data$n_exercises,
      sessions_per_week = .data$n_sessions / .data$intervention_weeks,
      load_category = factor(
        dplyr::if_else(.data$high_load_share >= 0.5, "High load", "Low load"),
        levels = c("High load", "Low load")
      ),
      failure_category = factor(
        dplyr::if_else(.data$failure_share >= 0.5, "To failure", "Short of failure"),
        levels = c("To failure", "Short of failure")
      ),
      training_status = factor(
        dplyr::if_else(.data$training_exp_m > 0, "Trained", "Untrained"),
        levels = c("Untrained", "Trained")
      )
    ) |>
    dplyr::select(-"is_nontraining_control_group")
}

# Standardized mean change (baseline to post-intervention) for every arm x
# measure with usable summary statistics, using change-score standardization by
# the baseline SD (metafor "SMCR") and an assumed pre-post correlation.
compute_effect_sizes <- function(hub, arms, analysis) {
  timed <- hub$outcome |>
    dplyr::inner_join(dplyr::select(hub$arm_week, "arm_id", "week", "testing_week_type"), by = c("arm_id", "week")) |>
    dplyr::mutate(sd_use = dplyr::coalesce(.data$sd, .data$se * sqrt(.data$n)))

  pre <- timed |>
    dplyr::filter(.data$testing_week_type == "Baseline") |>
    dplyr::select("arm_id", "measure_id", n_pre = "n", mean_pre = "mean", sd_pre = "sd_use")
  post <- timed |>
    dplyr::filter(.data$testing_week_type == "Post-Intervention") |>
    dplyr::select("arm_id", "measure_id", week_post = "week", n_post = "n", mean_post = "mean")

  es <- dplyr::inner_join(pre, post, by = c("arm_id", "measure_id")) |>
    dplyr::mutate(n = pmin(.data$n_pre, .data$n_post)) |>
    dplyr::filter(!is.na(.data$mean_pre), !is.na(.data$mean_post), !is.na(.data$sd_pre), .data$sd_pre > 0, .data$n >= 2)

  smcr <- metafor::escalc(
    measure = "SMCR", m1i = es$mean_post, m2i = es$mean_pre, sd1i = es$sd_pre,
    ni = es$n, ri = rep(analysis$pre_post_r, nrow(es))
  )
  es$yi <- as.numeric(smcr$yi)
  es$vi <- as.numeric(smcr$vi)

  es |>
    dplyr::left_join(dplyr::select(hub$measure, "measure_id", "domain", "measurement"), by = "measure_id") |>
    dplyr::left_join(arms, by = "arm_id", suffix = c("", "_arm")) |>
    dplyr::left_join(dplyr::select(hub$study, "study_id", "first_author", "year"), by = "study_id") |>
    dplyr::mutate(es_id = paste(.data$arm_id, .data$measure_id, sep = "__")) |>
    dplyr::select(
      "es_id", "study_id", "first_author", "year", "arm_id", "arm_label", "measure_id",
      "domain", "measurement", "n", "yi", "vi", "is_control", "intervention_weeks",
      "weekly_sets", "sets_per_exercise_week", "sessions_per_week",
      "load_category", "failure_category", "training_status"
    ) |>
    dplyr::arrange(.data$es_id)
}

# Fit the pooled and moderated multilevel models for one outcome domain.
# Random effects: effect sizes nested in arms nested in studies.
fit_domain_models <- function(effect_sizes, domain, analysis) {
  d <- effect_sizes |>
    dplyr::filter(.data$domain == !!domain, !.data$is_control) |>
    dplyr::mutate(sets_c = .data$sets_per_exercise_week - analysis$sets_centre)
  if (dplyr::n_distinct(d$study_id) < analysis$min_studies_per_model) {
    stop("Too few studies for domain '", domain, "' (", dplyr::n_distinct(d$study_id), ").", call. = FALSE)
  }
  pooled <- fit_multilevel(d)
  moderated <- fit_multilevel(d, mods = ~ load_category + sets_c)
  list(domain = domain, data = d, pooled = pooled, moderated = moderated, sets_centre = analysis$sets_centre)
}

# Optimisers tried in order. nlminb (metafor's default) is used whenever it
# converges; the fallbacks exist because REML surfaces with a variance
# component near zero can make nlminb stop short on some platforms (seen on
# the Linux CI runner but not on Windows, with identical data).
RMA_OPTIMIZERS <- list(
  nlminb = list(),
  `optim-BFGS` = list(optimizer = "optim", optmethod = "BFGS"),
  `optim-Nelder-Mead` = list(optimizer = "optim", optmethod = "Nelder-Mead", maxit = 10000)
)

# Multilevel random-effects model: effect sizes nested in arms nested in
# studies (REML, t-tests). The optimiser that converged is stored in the
# "optimizer" attribute.
fit_multilevel <- function(d, mods = NULL) {
  failures <- character()
  for (name in names(RMA_OPTIMIZERS)) {
    args <- list(
      yi = d$yi, V = d$vi, random = list(~ 1 | study_id / arm_id / es_id),
      data = d, method = "REML", test = "t", control = RMA_OPTIMIZERS[[name]]
    )
    if (!is.null(mods)) args$mods <- mods # rma.mv rejects an explicit mods = NULL
    fit <- tryCatch(
      do.call(metafor::rma.mv, args),
      error = function(e) {
        failures[[name]] <<- conditionMessage(e)
        NULL
      }
    )
    if (!is.null(fit)) {
      attr(fit, "optimizer") <- name
      return(fit)
    }
  }
  stop("Multilevel model did not converge with any optimiser:
",
    paste0("  - ", names(failures), ": ", failures, collapse = "
"), call. = FALSE)
}

summarise_pooled <- function(models) {
  dplyr::bind_rows(lapply(models, function(m) {
    p <- stats::predict(m$pooled)
    tibble::tibble(
      domain = m$domain,
      k = m$pooled$k,
      n_arms = dplyr::n_distinct(m$data$arm_id),
      n_studies = dplyr::n_distinct(m$data$study_id),
      estimate = as.numeric(p$pred),
      ci_lb = as.numeric(p$ci.lb),
      ci_ub = as.numeric(p$ci.ub),
      pi_lb = as.numeric(p$pi.lb),
      pi_ub = as.numeric(p$pi.ub),
      sigma2_study = m$pooled$sigma2[1],
      sigma2_arm = m$pooled$sigma2[2],
      sigma2_es = m$pooled$sigma2[3],
      optimizer = attr(m$pooled, "optimizer")
    )
  }))
}

summarise_moderators <- function(models) {
  labels <- c(
    intrcpt = "Intercept",
    `load_categoryLow load` = "Low vs. high load",
    sets_c = "Per additional weekly set per exercise"
  )
  dplyr::bind_rows(lapply(models, function(m) {
    s <- m$moderated
    tibble::tibble(
      domain = m$domain,
      term = unname(labels[rownames(s$beta)]),
      estimate = as.numeric(s$beta),
      se = as.numeric(s$se),
      ci_lb = as.numeric(s$ci.lb),
      ci_ub = as.numeric(s$ci.ub),
      p_value = as.numeric(s$pval)
    )
  }))
}

# Model-implied mean effect by load category across a range of weekly sets.
predict_moderated <- function(model, sets_range, n = 50) {
  grid <- expand.grid(
    sets_per_exercise_week = seq(sets_range[1], sets_range[2], length.out = n),
    load_category = c("High load", "Low load"),
    stringsAsFactors = FALSE
  )
  newmods <- cbind(as.numeric(grid$load_category == "Low load"), grid$sets_per_exercise_week - model$sets_centre)
  p <- stats::predict(model$moderated, newmods = newmods)
  tibble::as_tibble(grid) |>
    dplyr::mutate(
      load_category = factor(.data$load_category, levels = c("High load", "Low load")),
      estimate = as.numeric(p$pred), ci_lb = as.numeric(p$ci.lb), ci_ub = as.numeric(p$ci.ub)
    )
}
