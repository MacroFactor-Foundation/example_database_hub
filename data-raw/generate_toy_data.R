# Generate the SYNTHETIC example tables in data/.
#
# This hub is a worked example of the living-database pattern. Its data are
# toy data: 50 fictional resistance-training studies whose structure and rough
# distributions resemble a real extraction corpus, but whose authors, titles,
# DOIs (10.5555 is a reserved example prefix) and values are all invented.
#
# In a real hub this script would not exist: tables are curated by hand and
# changed through reviewed pull requests. Here it makes the example data
# reproducible. Run from the project root:
#
#   Rscript data-raw/generate_toy_data.R
#
# Deterministic: the same script and seed produce byte-identical CSVs.

suppressPackageStartupMessages(library(dplyr))

RNGkind("Mersenne-Twister", "Inversion", "Rejection")
set.seed(20260923)

N_STUDIES <- 50
PRE_POST_R <- 0.8 # true pre-post correlation used to simulate outcomes

schema <- yaml::read_yaml("config/schema.yml")

pick <- function(x, prob = NULL) x[sample.int(length(x), 1, prob = prob)]
coin <- function(p) stats::runif(1) < p
rnd <- function(x, digits = 1) round(x, digits)

# ---- catalogues ----------------------------------------------------------------

surnames <- c(
  "Hartley", "Okonkwo", "Lindqvist", "Moreau", "Tanabe", "Brennan", "Castellano",
  "Novak", "Achterberg", "Figueira", "Kowalczyk", "Rahimi", "Duarte", "Fenwick",
  "Iversen", "Jansen", "Kaur", "Laurent", "Mwangi", "Oduya", "Petrakis", "Quinlan",
  "Rosales", "Sandoval", "Takeda", "Uribe", "Whitlock", "Yilmaz", "Zielinski",
  "Abernathy", "Barros", "Chandra", "Delacroix", "Ekberg", "Fairbanks", "Gallardo",
  "Haugen", "Ishikawa", "Jovanovic", "Varga"
)

exercises <- tibble::tribble(
  ~exercise,                  ~implement,      ~pattern,                  ~lower,
  "Flat Barbell Press",       "Barbell",       "Bench Press",             FALSE,
  "Smith-Machine Bench Press", "Smith-Machine", "Bench Press",            FALSE,
  "Dumbbell Chest Fly",       "Dumbbell",      "Chest Fly",               FALSE,
  "Barbell Military Press",   "Barbell",       "Shoulder Press",          FALSE,
  "Dumbbell Lateral Raise",   "Dumbbell",      "Lateral Raise",           FALSE,
  "Wide-Grip Lat Pull-Down",  "Cable",         "Pulldown",                FALSE,
  "Seated Cable Row",         "Cable",         "Row",                     FALSE,
  "Barbell Biceps Curl",      "Barbell",       "Elbow Flexion",           FALSE,
  "Cable Triceps Pushdown",   "Cable",         "Elbow Extension",         FALSE,
  "Parallel Back Squat",      "Barbell",       "Back Squat",              TRUE,
  "Leg Press",                "Machine",       "Leg Press",               TRUE,
  "Dumbbell Walking Lunge",   "Dumbbell",      "Lunge",                   TRUE,
  "Romanian Deadlift",        "Barbell",       "Deadlift",                TRUE,
  "Barbell Hip Thrust",       "Barbell",       "Hip Thrust",              TRUE,
  "Leg Extension",            "Machine",       "Knee Extension",          TRUE,
  "Seated Leg Curl",          "Machine",       "Knee Flexion",            TRUE,
  "Standing Calf Raise",      "Machine",       "Straight Leg Calf Raise", TRUE
)

# Outcome measures with plausible baseline means (male, female) and SD as a
# fraction of the mean. `region` controls which studies can use the measure.
measures <- tibble::tribble(
  ~domain, ~measurement, ~device, ~device_value, ~muscle_assessed, ~muscle_region, ~implement, ~pattern, ~contraction_type, ~rm_value, ~measurement_units, ~base_m, ~base_f, ~sd_frac, ~region, ~digits,
  "Hypertrophy", "Elbow Flexor Thickness", "B-mode US", "Muscle Thickness", "BBLH,BBSH,BRA", "Middle", NA, NA, NA, NA, "mm", 38, 28, 0.13, "upper", 1,
  "Hypertrophy", "Elbow Extensor Thickness", "B-mode US", "Muscle Thickness", "TBLH,TBLAT,TBMED", "Middle", NA, NA, NA, NA, "mm", 42, 32, 0.14, "upper", 1,
  "Hypertrophy", "Pectoralis Major Thickness", "B-mode US", "Muscle Thickness", "PM", "Middle", NA, NA, NA, NA, "mm", 25, 17, 0.16, "upper", 1,
  "Hypertrophy", "Quadriceps Femoris Thickness", "B-mode US", "Muscle Thickness", "RF,VI", "Middle", NA, NA, NA, NA, "mm", 52, 44, 0.14, "lower", 1,
  "Hypertrophy", "Vastus Lateralis Cross-Sectional Area", "MRI", "Muscle Cross-Sectional Area", "VL", "Middle", NA, NA, NA, NA, "cm²", 32, 24, 0.18, "lower", 1,
  "Hypertrophy", "Vastus Lateralis Type II Fiber Area", "Muscle Biopsy", "Type II Muscle Fiber Cross-Sectional Area", "VL", NA, NA, NA, NA, NA, "micrometers squared", 6200, 4800, 0.22, "lower", 0,
  "Hypertrophy", "Medial Gastrocnemius Thickness", "B-mode US", "Muscle Thickness", "GMH", "Proximal", NA, NA, NA, NA, "mm", 20, 17, 0.12, "lower", 1,
  "Strength", "Flat Barbell Press 1RM", NA, NA, NA, NA, "Barbell", "Bench Press", "Isotonic", 1L, "kg", 85, 42, 0.20, "upper", 1,
  "Strength", "Barbell Biceps Curl 1RM", NA, NA, NA, NA, "Barbell", "Elbow Flexion", "Isotonic", 1L, "kg", 42, 22, 0.20, "upper", 1,
  "Strength", "Parallel Back Squat 1RM", NA, NA, NA, NA, "Barbell", "Back Squat", "Isotonic", 1L, "kg", 115, 70, 0.20, "lower", 1,
  "Strength", "Leg Press 1RM", NA, NA, NA, NA, "Machine", "Leg Press", "Isotonic", 1L, "kg", 230, 150, 0.22, "lower", 0,
  "Strength", "Knee Extension Isometric Peak Torque", NA, NA, NA, NA, "Isokinetic Dynamometer", "Knee Extension", "Isometric", NA, "N·m", 260, 170, 0.20, "lower", 1,
  "Strength", "Knee Extension Isokinetic Peak Torque", NA, NA, NA, NA, "Isokinetic Dynamometer", "Knee Extension", "Isokinetic", NA, "N·m", 210, 140, 0.20, "lower", 1,
  "Body Composition", "Whole-Body Lean Mass", "DXA", "Lean Mass", NA, NA, NA, NA, NA, NA, "kg", 60, 42, 0.12, "whole", 1,
  "Body Composition", "Whole-Body Fat Mass", "DXA", "Fat Mass", NA, NA, NA, NA, NA, NA, "kg", 15, 20, 0.35, "whole", 1,
  "Absolute Muscular Endurance", "Flat Barbell Press Repetitions at a Fixed Load", NA, NA, NA, NA, "Barbell", "Bench Press", "Isotonic", NA, "repetitions", 18, 12, 0.30, "upper", 1,
  "Absolute Muscular Endurance", "Leg Extension Repetitions at a Fixed Load", NA, NA, NA, NA, "Machine", "Knee Extension", "Isotonic", NA, "repetitions", 20, 16, 0.30, "lower", 1,
  "Circumference", "Mid-Thigh Circumference", "Tape Measure", "Circumference", "RF,VL,VI,VM", "Middle", NA, NA, NA, NA, "cm", 56, 52, 0.08, "lower", 1
)

# True standardized change for a training arm (the "answer" the example
# analyses should roughly recover).
true_smd <- function(domain, measurement, arm, study) {
  base <- switch(domain,
    "Hypertrophy" = 0.30, "Strength" = 0.75, "Body Composition" = 0.18,
    "Absolute Muscular Endurance" = 0.60, "Circumference" = 0.15
  )
  if (measurement == "Whole-Body Fat Mass") base <- -0.08
  dose <- arm$sets_per_exercise_week - 6
  slope <- switch(domain, "Hypertrophy" = 0.030, "Strength" = 0.015, 0.010)
  load <- switch(domain,
    "Strength" = if (arm$high_load) 0.25 else 0,
    "Absolute Muscular Endurance" = if (arm$high_load) 0 else 0.25,
    0
  )
  fail <- if (arm$failure && domain == "Hypertrophy") 0.03 else 0
  scale <- (if (study$trained) 0.6 else 1) * (if (study$older) 0.9 else 1)
  (base + slope * dose + load + fail) * scale
}

# ---- studies -------------------------------------------------------------------

population_label <- function(sex, trained, older) {
  who <- switch(sex, male = "men", female = "women", mixed = "men and women")
  if (older) return(paste("older", who))
  paste(if (trained) "resistance-trained" else "untrained", who)
}

title_for <- function(type, weeks, pop) {
  lead <- switch(type,
    load = "Effects of low- versus high-load resistance training on muscle strength and hypertrophy",
    volume = "Dose-response effects of weekly set volume on muscle growth and strength",
    failure = "Training to failure versus stopping short: effects on hypertrophy and strength",
    frequency = "Volume-equated training frequency and muscular adaptations"
  )
  paste0(lead, ": a ", weeks, "-week trial in ", pop)
}

make_study <- function(i) {
  design <- pick(
    c("Parallel Group", "Within-Participant Unilateral", "Parallel Group + Within-Participant Unilateral", "Within-Participant Crossover"),
    c(0.86, 0.10, 0.03, 0.01)
  )
  older <- coin(0.15)
  s <- list(
    first_author = pick(surnames),
    year = pick(1998:2026, seq(1, 4, length.out = 29)),
    type = pick(c("load", "volume", "failure", "frequency"), c(0.35, 0.30, 0.20, 0.15)),
    design = design,
    unilateral = design != "Parallel Group",
    older = older,
    trained = !older && coin(0.4),
    sex = pick(c("male", "female", "mixed"), c(0.55, 0.20, 0.25)),
    control = design == "Parallel Group" && coin(0.25),
    n_arms = if (design == "Parallel Group") pick(2:4, c(0.6, 0.28, 0.12)) else 2L,
    weeks = pick(6:16, c(1, 2, 4, 4, 5, 4, 3, 3, 2, 1, 1)),
    mid_test = coin(0.35),
    pre_baseline = coin(0.30),
    standardized = coin(0.12),
    reduced_week = coin(0.08),
    break_week = coin(0.10),
    supersets = coin(0.08),
    tempo = if (coin(0.55)) c(pick(c(2, 3)), 0, pick(c(1, NA))) else c(NA, NA, NA),
    rest = pick(c(1, 1.5, 2, 3)),
    load_style = pick(c("RM", "%1RM")),
    ptf_style = pick(c("FAIL", "RIR"), c(0.6, 0.4)),
    failure_definition = pick(c("Momentary Muscular Failure", "Concentric Failure", "Volitional Failure", "Momentary Concentric Muscular Failure")),
    sessions = pick(2:3),
    report_se = coin(0.10),
    report_dropouts = coin(0.8),
    report_bmi = coin(0.2),
    report_contrast = coin(0.35),
    relative_contrast = coin(0.10),
    report_reliability = coin(0.5)
  )
  if (s$type == "load" && s$n_arms > 3) s$n_arms <- 3L
  if (s$type == "frequency" && s$n_arms > 3) s$n_arms <- 3L
  s
}

studies <- lapply(seq_len(N_STUDIES), make_study)

slug <- function(x) gsub("[^a-z]", "", tolower(iconv(x, to = "ASCII//TRANSLIT")))
keys <- vapply(studies, function(s) paste0(slug(s$first_author), s$year), character(1))
suffix <- letters[stats::ave(seq_along(keys), keys, FUN = seq_along)]
for (i in seq_along(studies)) studies[[i]]$study_id <- paste0(keys[i], suffix[i])

yn <- function(x) if (isTRUE(x)) "Yes" else "No"

study_tbl <- bind_rows(lapply(studies, function(s) {
  pop <- population_label(s$sex, s$trained, s$older)
  tibble::tibble(
    study_id = s$study_id,
    first_author = s$first_author,
    year = as.integer(s$year),
    doi = paste0("10.5555/toy.", s$study_id),
    title = title_for(s$type, s$weeks, pop),
    randomized = pick(c("Yes", "No", "Unclear"), c(0.95, 0.03, 0.02)),
    design = s$design,
    nutrition_controlled = pick(c("Unclear", "No", "Yes"), c(0.45, 0.40, 0.15)),
    control_condition = yn(s$control),
    bfr_condition = "No",
    concurrent_training = yn(coin(0.05)),
    uncontrolled_training = yn(coin(0.10)),
    standardized_training = yn(s$standardized),
    washout_period = yn(s$design == "Within-Participant Crossover"),
    reduced_training_weeks = yn(s$reduced_week),
    no_training_weeks = yn(s$break_week),
    supplementation = yn(coin(0.2))
  )
}))

# ---- arms and programs --------------------------------------------------------

arm_programs <- function(s) {
  k <- s$n_arms
  base <- list(
    sessions = s$sessions, sets = 3L,
    load = if (s$load_style == "RM") list(type = "RM", rm = c(8L, 12L), load = c(NA, NA)) else list(type = "%1RM", rm = c(NA, NA), load = c(70, 75)),
    reps = c(8L, 12L),
    ptf = if (s$ptf_style == "FAIL") list(type = "FAIL", value = 0) else list(type = "RIR", value = pick(1:2)),
    high_load = TRUE
  )
  loads <- list(
    HL = list(rm = c(6L, 10L), load = c(80, 85), reps = c(6L, 10L), high = TRUE),
    ML = list(rm = c(12L, 15L), load = c(65, 70), reps = c(12L, 15L), high = TRUE),
    LL = list(rm = c(25L, 35L), load = c(30, 50), reps = c(25L, 35L), high = FALSE)
  )
  arms <- switch(s$type,
    load = {
      labels <- if (k == 2) c("HL", "LL") else c("HL", "ML", "LL")
      lapply(labels, function(l) {
        a <- base
        a$load$rm <- if (a$load$type == "RM") loads[[l]]$rm else c(NA, NA)
        a$load$load <- if (a$load$type == "%1RM") loads[[l]]$load else c(NA, NA)
        a$reps <- loads[[l]]$reps
        a$high_load <- loads[[l]]$high
        a$ptf <- list(type = "FAIL", value = 0)
        a$label <- l
        a
      })
    },
    volume = {
      sets <- list(`2` = c(2L, 5L), `3` = c(1L, 3L, 5L), `4` = c(1L, 2L, 4L, 6L))[[as.character(k)]]
      lapply(sets, function(n) {
        a <- base
        a$sets <- n
        a$label <- paste0(n, "SET")
        a
      })
    },
    failure = {
      rir <- list(`2` = c(0, 3), `3` = c(0, 1, 3), `4` = c(0, 1, 3, 5))[[as.character(k)]]
      lapply(rir, function(r) {
        a <- base
        a$ptf <- if (r == 0) list(type = "FAIL", value = 0) else list(type = "RIR", value = r)
        a$label <- if (r == 0) "FAIL" else paste0("RIR", r)
        a
      })
    },
    frequency = {
      freq <- if (k == 2) c(1L, 3L) else c(1L, 2L, 3L)
      lapply(freq, function(f) {
        a <- base
        a$sessions <- f
        a$sets <- as.integer(6L / f)
        a$label <- paste0("F", f)
        a
      })
    }
  )
  for (i in seq_along(arms)) {
    arms[[i]]$control <- FALSE
    arms[[i]]$failure <- arms[[i]]$ptf$type == "FAIL"
    arms[[i]]$sets_per_exercise_week <- arms[[i]]$sessions * arms[[i]]$sets
  }
  if (s$control) arms <- c(arms, list(list(label = "CON", control = TRUE)))
  arms
}

sample_arm <- function(s, a, shared) {
  male <- switch(s$sex, male = 1, female = 0, mixed = rnd(stats::runif(1, 0.35, 0.65), 2))
  n <- if (s$unilateral) shared$n else sample(8:22, 1)
  mass <- switch(s$sex, male = 80, female = 62, mixed = 71) + stats::rnorm(1, 0, 3)
  height <- switch(s$sex, male = 178, female = 165, mixed = 171) + stats::rnorm(1, 0, 2)
  age <- if (s$older) stats::rnorm(1, 67, 3) else stats::rnorm(1, 23, 1.8)
  exp <- if (s$trained) stats::runif(1, 1.5, 6) else 0
  src <- if (s$unilateral) shared else list(male = male, mass = mass, height = height, age = age, exp = exp)
  age_sd <- stats::runif(1, 1.5, if (s$older) 6 else 4)
  tibble::tibble(
    arm_label = a$label,
    is_nontraining_control_group = yn(a$control),
    used_bfr = "No",
    load_adjustments = if (a$control) NA_character_ else pick(c("Yes", "No"), c(0.85, 0.15)),
    progression = if (a$control) NA_character_ else pick(c("Yes", "No", "Unclear"), c(0.7, 0.2, 0.1)),
    n = as.integer(n),
    n_dropouts = if (s$report_dropouts) as.integer(min(stats::rpois(1, 1.5), 6)) else NA_integer_,
    proportion_male = src$male,
    age_m = rnd(src$age),
    age_sd = if (s$report_se) NA_real_ else rnd(age_sd),
    age_se = if (s$report_se) rnd(age_sd / sqrt(n), 2) else NA_real_,
    body_mass_m = rnd(src$mass),
    body_mass_sd = if (s$report_se) NA_real_ else rnd(stats::runif(1, 7, 12)),
    body_mass_se = if (s$report_se) rnd(stats::runif(1, 7, 12) / sqrt(n), 2) else NA_real_,
    height_m = rnd(src$height),
    height_sd = if (s$report_se) NA_real_ else rnd(stats::runif(1, 5, 8)),
    height_se = if (s$report_se) rnd(stats::runif(1, 5, 8) / sqrt(n), 2) else NA_real_,
    bmi_m = if (s$report_bmi) rnd(src$mass / (src$height / 100)^2) else NA_real_,
    bmi_sd = if (s$report_bmi) rnd(stats::runif(1, 1.8, 3.2)) else NA_real_,
    bmi_se = NA_real_,
    training_exp_m = rnd(src$exp),
    training_exp_sd = if (s$trained && coin(0.4)) rnd(stats::runif(1, 0.8, 2.5)) else NA_real_,
    training_exp_se = NA_real_
  )
}

# ---- timeline ------------------------------------------------------------------

study_timeline <- function(s) {
  training_weeks <- s$weeks + s$break_week
  weeks <- data.frame(week = 0:(training_weeks + 1), testing = "No Testing", training = "Training", stringsAsFactors = FALSE)
  weeks$testing[weeks$week == 0] <- "Baseline"
  weeks$training[weeks$week == 0] <- "No Training"
  post <- training_weeks + 1
  weeks$testing[weeks$week == post] <- "Post-Intervention"
  weeks$training[weeks$week == post] <- "No Training"
  mid <- ceiling(training_weeks / 2)
  if (s$break_week) weeks$training[weeks$week == mid + 1] <- "No Training"
  if (s$reduced_week) weeks$training[weeks$week == training_weeks - 1] <- "Reduced Training"
  if (s$mid_test) weeks$testing[weeks$week == mid] <- "Mid-Intervention"
  lead_in <- NULL
  if (s$standardized) lead_in <- data.frame(week = -3:-1, testing = "No Testing", training = "Standardized Training")
  if (s$pre_baseline) {
    first <- if (is.null(lead_in)) -1 else -4
    lead_in <- rbind(data.frame(week = first, testing = "Pre-Baseline", training = "No Training"), lead_in)
  }
  rbind(lead_in, weeks)
}

# ---- build every table ---------------------------------------------------------

arm_rows <- list(); week_rows <- list(); set_rows <- list()
measure_rows <- list(); outcome_rows <- list(); contrast_rows <- list(); reliability_rows <- list()

for (s in studies) {
  arms <- arm_programs(s)
  shared <- list(
    n = sample(10:22, 1),
    male = switch(s$sex, male = 1, female = 0, mixed = rnd(stats::runif(1, 0.35, 0.65), 2)),
    mass = switch(s$sex, male = 80, female = 62, mixed = 71) + stats::rnorm(1, 0, 3),
    height = switch(s$sex, male = 178, female = 165, mixed = 171) + stats::rnorm(1, 0, 2),
    age = if (s$older) stats::rnorm(1, 67, 3) else stats::rnorm(1, 23, 1.8),
    exp = if (s$trained) stats::runif(1, 1.5, 6) else 0
  )
  timeline <- study_timeline(s)
  post_week <- timeline$week[timeline$testing == "Post-Intervention"]
  mid_week <- timeline$week[timeline$testing == "Mid-Intervention"]

  # Program: unilateral designs train the legs only.
  pool <- if (s$unilateral) exercises[exercises$lower, ] else exercises
  n_ex <- if (s$unilateral) sample(1:2, 1) else sample(3:5, 1)
  program <- pool[sort(sample.int(nrow(pool), n_ex)), ]
  if (!s$unilateral && !any(program$lower)) program[n_ex, ] <- exercises[exercises$exercise == "Leg Press", ]

  # Measures: mostly strength + hypertrophy, matched to the trained region.
  region_ok <- if (s$unilateral) measures$region %in% c("lower") else rep(TRUE, nrow(measures))
  cand <- which(region_ok & measures$domain %in% c("Hypertrophy", "Strength"))
  chosen <- sample(cand, min(length(cand), sample(2:4, 1)))
  if (!s$unilateral && coin(0.30)) chosen <- c(chosen, which(measures$domain == "Body Composition")[seq_len(pick(1:2))])
  if (coin(0.20)) chosen <- c(chosen, pick(which(region_ok & measures$domain == "Absolute Muscular Endurance")))
  if (coin(0.10)) chosen <- c(chosen, which(measures$domain == "Circumference"))
  chosen <- unique(chosen)
  m_tbl <- measures[chosen, ]
  m_tbl$measure_id <- sprintf("%s_m%02d", s$study_id, seq_len(nrow(m_tbl)))
  m_tbl$study_id <- s$study_id
  measure_rows[[s$study_id]] <- m_tbl

  study_re <- stats::rnorm(1, 0, 0.12)
  sex_mix <- switch(s$sex, male = 1, female = 0, mixed = 0.5)
  base_scale <- function(m) {
    b <- sex_mix * m$base_m + (1 - sex_mix) * m$base_f
    if (m$domain == "Strength") b <- b * (if (s$trained) 1.25 else 1) * (if (s$older) 0.75 else 1)
    if (m$domain == "Hypertrophy") b <- b * (if (s$trained) 1.1 else 1) * (if (s$older) 0.85 else 1)
    b
  }
  mu_pre <- vapply(seq_len(nrow(m_tbl)), function(j) base_scale(m_tbl[j, ]), numeric(1))

  for (a in arms) {
    arm <- sample_arm(s, a, shared)
    arm_id <- paste0(s$study_id, "_", tolower(gsub("[^A-Za-z0-9]", "", a$label)))
    arm_rows[[arm_id]] <- tibble::add_column(arm, arm_id = arm_id, study_id = s$study_id, .before = 1)

    tl <- timeline
    if (a$control) tl$training[tl$training %in% c("Training", "Reduced Training") | (tl$training == "No Training" & tl$testing == "No Testing")] <- "Non-Training Control"
    week_rows[[arm_id]] <- tibble::tibble(arm_id = arm_id, week = as.integer(tl$week), testing_week_type = tl$testing, training_week_type = tl$training)

    # Training sets for every week that involves training.
    if (!a$control) {
      for (w in tl$week[tl$training %in% c("Training", "Reduced Training", "Standardized Training")]) {
        wtype <- tl$training[tl$week == w]
        std <- wtype == "Standardized Training"
        sets <- if (std) 2L else if (wtype == "Reduced Training") as.integer(ceiling(a$sets / 2)) else a$sets
        sessions <- if (std) 2L else a$sessions
        g <- expand.grid(set = seq_len(sets), exercise_order = seq_len(nrow(program)), session = seq_len(sessions))
        g <- g[order(g$session, g$exercise_order, g$set), ]
        ex <- program[g$exercise_order, ]
        load <- if (std) list(type = "RM", rm = c(10L, 12L), load = c(NA, NA)) else a$load
        reps <- if (std) c(10L, 12L) else a$reps
        ptf <- if (std) list(type = "RIR", value = 2) else a$ptf
        link_id <- link_type <- link_sequence <- rep(NA, nrow(g))
        if (s$supersets && nrow(program) >= 2) {
          pair <- ceiling(g$exercise_order / 2)
          paired <- pair * 2 <= nrow(program)
          link_id[paired] <- (pair[paired] - 1) * sets + g$set[paired]
          link_type[paired] <- "Inter-Exercise"
          link_sequence[paired] <- 2 - g$exercise_order[paired] %% 2
        }
        set_rows[[length(set_rows) + 1]] <- tibble::tibble(
          arm_id = arm_id, week = as.integer(w), session = as.integer(g$session),
          exercise_order = as.integer(g$exercise_order), set = as.integer(g$set),
          link_id = as.integer(link_id), link_type = as.character(link_type), link_sequence = as.integer(link_sequence),
          exercise = ex$exercise, implement = ex$implement, pattern = ex$pattern,
          reps_min = reps[1], reps_max = reps[2],
          relative_load_type = load$type,
          relative_load_min = load$load[1], relative_load_max = load$load[2],
          rm_min = load$rm[1], rm_max = load$rm[2],
          ptf_type = ptf$type,
          failure_definition = if (ptf$type == "FAIL") s$failure_definition else NA_character_,
          ptf = ptf$value,
          velocity_loss = NA_real_,
          tempo_eccentric = s$tempo[1], tempo_pause = s$tempo[2], tempo_concentric = s$tempo[3],
          rest_intra_set = NA_real_,
          rest_inter_set = ifelse(g$set == sets, NA_real_, s$rest)
        )
      }
    }

    # Outcomes at baseline, (mid) and post.
    arm_re <- stats::rnorm(1, 0, 0.06)
    for (j in seq_len(nrow(m_tbl))) {
      m <- m_tbl[j, ]
      sd_true <- mu_pre[j] * m$sd_frac
      delta <- if (a$control) stats::rnorm(1, 0, 0.03) else true_smd(m$domain, m$measurement, a, s) + study_re + arm_re
      n <- arm$n
      pre <- mu_pre[j] + stats::rnorm(1, 0, sd_true / sqrt(n))
      change_noise <- function() stats::rnorm(1, 0, sd_true * sqrt(2 * (1 - PRE_POST_R)) / sqrt(n))
      post <- pre + delta * sd_true + change_noise()
      sd_pre <- sd_true * stats::runif(1, 0.85, 1.15)
      sd_post <- sd_pre * stats::runif(1, 0.95, 1.10)
      wk <- c(0L, if (length(mid_week)) as.integer(mid_week), as.integer(post_week))
      means <- c(pre, if (length(mid_week)) pre + (post - pre) * 0.55 + change_noise() / 2, post)
      sds <- c(sd_pre, if (length(mid_week)) (sd_pre + sd_post) / 2, sd_post)
      outcome_rows[[length(outcome_rows) + 1]] <- tibble::tibble(
        arm_id = arm_id, measure_id = m$measure_id, week = wk, n = as.integer(n),
        mean = rnd(means, m$digits),
        sd = if (s$report_se) NA_real_ else rnd(sds, m$digits + 1),
        se = if (s$report_se) rnd(sds / sqrt(n), m$digits + 1) else NA_real_
      )

      if (s$report_contrast) {
        diff <- post - pre
        sd_diff <- sd_true * sqrt(2 * (1 - PRE_POST_R)) * stats::runif(1, 0.9, 1.1)
        t <- diff / (sd_diff / sqrt(n))
        style <- pick(c("sd", "p", "ci"), c(0.45, 0.35, 0.20))
        rel <- s$relative_contrast
        md <- if (rel) 100 * diff / pre else diff
        sdd <- if (rel) 100 * sd_diff / pre else sd_diff
        half <- stats::qt(0.975, n - 1) * sdd / sqrt(n)
        contrast_rows[[length(contrast_rows) + 1]] <- tibble::tibble(
          arm_id = arm_id, measure_id = m$measure_id,
          week_high = as.integer(post_week), week_low = 0L, n_diff = as.integer(n),
          mean_diff = rnd(md, 2),
          sd_diff = if (style == "sd") rnd(sdd, 2) else NA_real_,
          se_diff = NA_real_,
          ci_level_diff = if (style == "ci") 95 else NA_real_,
          ci_low_diff = if (style == "ci") rnd(md - half, 2) else NA_real_,
          ci_high_diff = if (style == "ci") rnd(md + half, 2) else NA_real_,
          t_value_diff = NA_real_,
          p_value_diff = if (style == "p") signif(max(2 * stats::pt(-abs(t), n - 1), 1e-4), 2) else NA_real_,
          flag_relative_difference = yn(rel),
          flag_standardized_difference = "No"
        )
      }
    }
  }

  if (s$report_reliability) {
    for (j in sort(sample.int(nrow(m_tbl), min(nrow(m_tbl), sample(1:3, 1))))) {
      stat <- pick(c("ICC", "CV"), c(0.7, 0.3))
      est <- if (stat == "ICC") rnd(stats::runif(1, 0.85, 0.99), 3) else rnd(stats::runif(1, 1, 5), 2)
      in_study <- s$pre_baseline && coin(0.5)
      with_ci <- stat == "ICC" && coin(0.3)
      reliability_rows[[length(reliability_rows) + 1]] <- tibble::tibble(
        reliability_id = paste0(m_tbl$measure_id[j], "_r1"),
        measure_id = m_tbl$measure_id[j],
        statistic = stat,
        estimate = est,
        statistic_units = if (stat == "CV") "%" else NA_character_,
        week = if (in_study) as.integer(min(timeline$week)) else NA_integer_,
        testing_week_type = if (in_study) "Pre-Baseline" else "Reliability Testing",
        n = if (coin(0.5)) as.integer(sample(8:20, 1)) else NA_integer_,
        se_reli = NA_real_,
        ci_level_reli = if (with_ci) 95 else NA_real_,
        ci_low_reli = if (with_ci) rnd(est - stats::runif(1, 0.02, 0.06), 3) else NA_real_,
        ci_high_reli = if (with_ci) rnd(min(0.999, est + stats::runif(1, 0.005, 0.02)), 3) else NA_real_
      )
    }
  }
}

# ---- write ---------------------------------------------------------------------

write_table <- function(df, name) {
  spec <- schema$tables[[name]]
  cols <- names(spec$columns)
  missing <- setdiff(cols, names(df))
  if (length(missing)) stop("Generator is missing columns for ", name, ": ", paste(missing, collapse = ", "))
  readr::write_csv(df[cols], spec$file, na = "", eol = "\n")
  message(sprintf("%-14s %6d rows -> %s", name, nrow(df), spec$file))
}

write_table(study_tbl, "study")
write_table(bind_rows(arm_rows), "arm")
write_table(bind_rows(week_rows), "arm_week")
write_table(bind_rows(set_rows), "training_set")
write_table(bind_rows(measure_rows), "measure")
write_table(bind_rows(outcome_rows), "outcome")
write_table(bind_rows(contrast_rows), "contrast")
write_table(bind_rows(reliability_rows), "reliability")
