<!-- Generated from config/schema.yml by scripts/build_data_dictionary.R. Do not edit by hand. -->

# Data dictionary

> **These tables contain synthetic toy data.** They reproduce the structure of a real
> resistance-training extraction corpus, but every study, author, DOI and value is invented
> (see `data-raw/generate_toy_data.R`). Do not use them for inference.

One CSV per normalized entity, joined by stable identifiers that are assigned once and never
reused or renumbered. Files are UTF-8, comma-separated, LF line endings, with an empty field
meaning *missing* (the literal text `NA` is a value, and will fail vocabulary checks).

Every rule below is enforced by `R/validate.R` on each pull request
(`.github/workflows/validate-data.yml`). To add or change a column, edit
`config/schema.yml`, regenerate this file, and update the affected CSVs in the same pull request.

## How the tables relate

- `study` has many `arm`s and many `measure`s.
- `arm` has many `arm_week`s (its timeline); each `arm_week` has many `training_set`s.
- `outcome` and `contrast` rows each reference an arm-week *and* a measure, which must belong
  to the same study.
- `reliability` rows reference a `measure`.

## `study`

One row per study (publication).

- **File:** `data/study.csv`
- **One row per:** study
- **Primary key:** (study_id)

| Column | Type | Required | Allowed | Description |
| :--- | :--- | :--- | :--- | :--- |
| `study_id` | string | yes | pattern `^[a-z]+[0-9]{4}[a-z]$` | Stable study identifier. First-author surname (lowercase ASCII) + year + a letter disambiguator, e.g. hartley2019a. Assigned once, never reused. |
| `first_author` | string | yes |  | Surname of the first author. |
| `year` | integer | yes | ≥ 1950, ≤ 2100 | Publication year. |
| `doi` | string |  | pattern `^10\.[0-9]{4,9}/\S+$` | Digital Object Identifier without the https://doi.org/ prefix. |
| `title` | string | yes |  | Full publication title. |
| `randomized` | string | yes | `Yes`, `No`, `Unclear` | Whether allocation to arms (or limbs) was randomized. |
| `design` | string | yes | `Parallel Group`, `Within-Participant Unilateral`, `Parallel Group + Within-Participant Unilateral`, `Within-Participant Crossover` | Study design. |
| `nutrition_controlled` | string | yes | `Yes`, `No`, `Unclear` | Whether dietary intake was controlled or standardized. |
| `control_condition` | string | yes | `Yes`, `No` | Whether the study includes a non-training control arm. |
| `bfr_condition` | string | yes | `Yes`, `No` | Whether any arm used blood-flow restriction. |
| `concurrent_training` | string | yes | `Yes`, `No` | Whether any arm also performed concurrent (e.g. endurance) training. |
| `uncontrolled_training` | string | yes | `Yes`, `No` | Whether participants could perform additional uncontrolled training. |
| `standardized_training` | string | yes | `Yes`, `No` | Whether a standardized training block preceded the intervention. |
| `washout_period` | string | yes | `Yes`, `No` | Whether the design includes a washout period. |
| `reduced_training_weeks` | string | yes | `Yes`, `No` | Whether the intervention contains reduced-training (e.g. deload) weeks. |
| `no_training_weeks` | string | yes | `Yes`, `No` | Whether the intervention contains weeks with no training (excluding testing weeks). |
| `supplementation` | string | yes | `Yes`, `No` | Whether any arm received a nutritional supplement. |

## `arm`

One row per study arm (group, or limb condition in within-participant designs), with sample characteristics.

- **File:** `data/arm.csv`
- **One row per:** study arm
- **Primary key:** (arm_id)
- **Foreign keys:** (study_id) → `study` (study_id)

| Column | Type | Required | Allowed | Description |
| :--- | :--- | :--- | :--- | :--- |
| `arm_id` | string | yes | pattern `^[a-z]+[0-9]{4}[a-z]_[a-z0-9]+$` | Stable arm identifier, study_id + "_" + slug of the arm label, e.g. hartley2019a_hl. |
| `study_id` | string | yes |  | Study this arm belongs to. |
| `arm_label` | string | yes |  | Arm label as reported in the study (e.g. HL |
| `is_nontraining_control_group` | string | yes | `Yes`, `No` | Whether this arm is a non-training control. |
| `used_bfr` | string | yes | `Yes`, `No` | Whether this arm trained with blood-flow restriction. |
| `load_adjustments` | string |  | `Yes`, `No` | Whether loads were adjusted during the intervention. Missing for non-training controls. |
| `progression` | string |  | `Yes`, `No`, `Unclear` | Whether the program was progressed over time. Missing for non-training controls. |
| `n` | integer | yes | ≥ 1 | Participants analysed in this arm. |
| `n_dropouts` | integer |  | ≥ 0 | Participants who dropped out of this arm. |
| `proportion_male` | number |  | ≥ 0, ≤ 1 | Proportion of participants who were male. |
| `age_m` | number |  | ≥ 10, ≤ 100 | Mean age (years). |
| `age_sd` | number |  | ≥ 0 | SD of age (years). |
| `age_se` | number |  | ≥ 0 | SE of age (years); used when only an SE is reported. |
| `body_mass_m` | number |  | ≥ 20, ≤ 250 | Mean body mass (kg). |
| `body_mass_sd` | number |  | ≥ 0 | SD of body mass (kg). |
| `body_mass_se` | number |  | ≥ 0 | SE of body mass (kg). |
| `height_m` | number |  | ≥ 100, ≤ 230 | Mean height (cm). |
| `height_sd` | number |  | ≥ 0 | SD of height (cm). |
| `height_se` | number |  | ≥ 0 | SE of height (cm). |
| `bmi_m` | number |  | ≥ 10, ≤ 60 | Mean body-mass index (kg/m²). |
| `bmi_sd` | number |  | ≥ 0 | SD of body-mass index. |
| `bmi_se` | number |  | ≥ 0 | SE of body-mass index. |
| `training_exp_m` | number |  | ≥ 0 | Mean resistance-training experience (years). 0 = untrained. |
| `training_exp_sd` | number |  | ≥ 0 | SD of training experience (years). |
| `training_exp_se` | number |  | ≥ 0 | SE of training experience (years). |

## `arm_week`

The study timeline, one row per arm per week, recording what testing and training happened that week.

- **File:** `data/arm_week.csv`
- **One row per:** arm × week
- **Primary key:** (arm_id, week)
- **Foreign keys:** (arm_id) → `arm` (arm_id)

| Column | Type | Required | Allowed | Description |
| :--- | :--- | :--- | :--- | :--- |
| `arm_id` | string | yes |  | Arm. |
| `week` | integer | yes | ≥ -52, ≤ 156 | Study week relative to baseline testing (week 0). Negative weeks precede baseline. |
| `testing_week_type` | string | yes | vocabulary `testing_week_type` | Testing that took place this week. |
| `training_week_type` | string | yes | `Training`, `Standardized Training`, `Reduced Training`, `No Training`, `Non-Training Control` | Training that took place this week. |

## `training_set`

The prescribed training program at the level of individual sets.

- **File:** `data/training_set.csv`
- **One row per:** arm × week × session × exercise × set
- **Primary key:** (arm_id, week, session, exercise_order, set)
- **Foreign keys:** (arm_id, week) → `arm_week` (arm_id, week)

| Column | Type | Required | Allowed | Description |
| :--- | :--- | :--- | :--- | :--- |
| `arm_id` | string | yes |  | Arm. |
| `week` | integer | yes |  | Study week (see arm_week). |
| `session` | integer | yes | ≥ 1, ≤ 14 | Session number within the week. |
| `exercise_order` | integer | yes | ≥ 1, ≤ 30 | Position of the exercise within the session. |
| `set` | integer | yes | ≥ 1, ≤ 50 | Set number within the exercise. |
| `link_id` | integer |  | ≥ 1 | Identifier grouping sets performed back-to-back (supersets |
| `link_type` | string |  | `Inter-Exercise`, `Intra-Exercise` | Whether linked sets span exercises (Inter-Exercise) or are within one exercise (Intra-Exercise). |
| `link_sequence` | integer |  | ≥ 1 | Position of this set within its link. |
| `exercise` | string | yes |  | Exercise name. |
| `implement` | string |  | vocabulary `implement` | Equipment used. |
| `pattern` | string |  | vocabulary `pattern` | Movement pattern. |
| `reps_min` | integer |  | ≥ 1 | Prescribed repetitions (lower bound; equals reps_max when a single value was prescribed). |
| `reps_max` | integer |  | ≥ 1 | Prescribed repetitions (upper bound). |
| `relative_load_type` | string |  | `RM`, `%1RM`, `%XRM` | How load was prescribed. |
| `relative_load_min` | number |  | ≥ 0, ≤ 150 | Relative load (lower bound) |
| `relative_load_max` | number |  | ≥ 0, ≤ 150 | Relative load (upper bound). |
| `rm_min` | integer |  | ≥ 1 | Repetition-maximum target (lower bound) when relative_load_type is RM. |
| `rm_max` | integer |  | ≥ 1 | Repetition-maximum target (upper bound). |
| `ptf_type` | string |  | `FAIL`, `RM`, `RIR`, `RPE` | How proximity to failure was prescribed. |
| `failure_definition` | string |  | `Momentary Muscular Failure`, `Concentric Failure`, `Volitional Failure`, `Momentary Concentric Muscular Failure` | Definition of failure used when ptf_type is FAIL. |
| `ptf` | number |  | ≥ -5, ≤ 10 | Proximity-to-failure value in the unit implied by ptf_type (0 = failure; RIR = repetitions in reserve). |
| `velocity_loss` | number |  | ≥ 0, ≤ 100 | Velocity-loss threshold (%). Reserved; not yet extracted. |
| `tempo_eccentric` | number |  | ≥ 0, ≤ 20 | Eccentric phase duration (s). |
| `tempo_pause` | number |  | ≥ 0, ≤ 20 | Pause duration (s). |
| `tempo_concentric` | number |  | ≥ 0, ≤ 20 | Concentric phase duration (s). Missing when the concentric phase was volitional or not reported ("None" in the extraction sheet). |
| `rest_intra_set` | number |  | ≥ 0, ≤ 10 | Rest within a set (min) |
| `rest_inter_set` | number |  | ≥ 0, ≤ 15 | Rest after this set (min). Usually missing on the final set of an exercise. |

## `measure`

One row per outcome measure per study. Describes what was measured and how; the values themselves are in outcome, contrast and reliability.

- **File:** `data/measure.csv`
- **One row per:** study × outcome measure
- **Primary key:** (measure_id)
- **Foreign keys:** (study_id) → `study` (study_id)

| Column | Type | Required | Allowed | Description |
| :--- | :--- | :--- | :--- | :--- |
| `measure_id` | string | yes | pattern `^[a-z]+[0-9]{4}[a-z]_m[0-9]{2,}$` | Stable measure identifier, study_id + "_m" + a two-digit sequence number in order of entry, e.g. hartley2019a_m01. |
| `study_id` | string | yes |  | Study. |
| `domain` | string | yes | vocabulary `domain` | Outcome domain. |
| `measurement` | string | yes |  | Name of the measurement (e.g. Elbow Flexor Thickness |
| `device` | string |  | vocabulary `device` | Measurement device (morphological outcomes). |
| `device_value` | string |  | vocabulary `device_value` | Quantity the device measured. |
| `muscle_assessed` | string |  | comma-separated list of vocabulary `muscle` | Comma-separated muscle codes assessed (see the muscle vocabulary). |
| `muscle_region` | string |  | `Proximal`, `Middle`, `Distal` | Region of the muscle assessed. |
| `implement` | string |  | vocabulary `implement` | Equipment used for performance outcomes. |
| `pattern` | string |  | vocabulary `pattern` | Movement pattern for performance outcomes. |
| `contraction_type` | string |  | `Isotonic`, `Isometric`, `Isokinetic` | Contraction type for performance outcomes. |
| `rm_value` | integer |  | ≥ 1, ≤ 50 | Repetition maximum tested (e.g. 1 for a 1RM). |
| `measurement_units` | string | yes | vocabulary `measurement_units` | Units of the outcome values. |

## `outcome`

Summary statistics for an outcome measure in one arm at one testing week.

- **File:** `data/outcome.csv`
- **One row per:** arm × measure × week
- **Primary key:** (arm_id, measure_id, week)
- **Foreign keys:** (arm_id, week) → `arm_week` (arm_id, week); (measure_id) → `measure` (measure_id)

| Column | Type | Required | Allowed | Description |
| :--- | :--- | :--- | :--- | :--- |
| `arm_id` | string | yes |  | Arm. |
| `measure_id` | string | yes |  | Measure (must belong to the same study as the arm). |
| `week` | integer | yes |  | Testing week (see arm_week for its testing_week_type). |
| `n` | integer |  | ≥ 1 | Participants contributing to this value. |
| `mean` | number |  |  | Mean |
| `sd` | number |  | ≥ 0 | Standard deviation. |
| `se` | number |  | ≥ 0 | Standard error; used when only an SE is reported. |

## `contrast`

Within-arm change between two testing weeks, as reported by the study (used when change statistics are reported directly).

- **File:** `data/contrast.csv`
- **One row per:** arm × measure × week pair
- **Primary key:** (arm_id, measure_id, week_high, week_low)
- **Foreign keys:** (arm_id, week_high) → `arm_week` (arm_id, week); (arm_id, week_low) → `arm_week` (arm_id, week); (measure_id) → `measure` (measure_id)

| Column | Type | Required | Allowed | Description |
| :--- | :--- | :--- | :--- | :--- |
| `arm_id` | string | yes |  | Arm. |
| `measure_id` | string | yes |  | Measure (must belong to the same study as the arm). |
| `week_high` | integer | yes |  | Later testing week of the contrast. |
| `week_low` | integer | yes |  | Earlier testing week of the contrast. |
| `n_diff` | integer |  | ≥ 1 | Participants contributing to the change. |
| `mean_diff` | number |  |  | Mean change (later minus earlier) |
| `sd_diff` | number |  | ≥ 0 | SD of the change. |
| `se_diff` | number |  | ≥ 0 | SE of the change. |
| `ci_level_diff` | number |  | ≥ 50, ≤ 99.9 | Confidence level (%) of the reported interval. |
| `ci_low_diff` | number |  |  | Lower confidence limit of the change. |
| `ci_high_diff` | number |  |  | Upper confidence limit of the change. |
| `t_value_diff` | number |  |  | Reported t statistic for the change. |
| `p_value_diff` | number |  | ≥ 0, ≤ 1 | Reported p value for the change. |
| `flag_relative_difference` | string | yes | `Yes`, `No` | Yes when mean_diff is a percentage change. |
| `flag_standardized_difference` | string | yes | `Yes`, `No` | Yes when mean_diff is a standardized (unitless) change. |

## `reliability`

Reliability statistics reported for a study's outcome measures.

- **File:** `data/reliability.csv`
- **One row per:** reported reliability statistic
- **Primary key:** (reliability_id)
- **Foreign keys:** (measure_id) → `measure` (measure_id)

| Column | Type | Required | Allowed | Description |
| :--- | :--- | :--- | :--- | :--- |
| `reliability_id` | string | yes | pattern `^[a-z]+[0-9]{4}[a-z]_m[0-9]{2,}_r[0-9]+$` | Stable identifier, measure_id + "_r" + a sequence number, e.g. hartley2019a_m01_r1. |
| `measure_id` | string | yes |  | Measure the statistic describes. |
| `statistic` | string | yes | `ICC`, `CV`, `SEM`, `TE`, `MDC` | Reliability statistic. |
| `estimate` | number |  |  | Reported value of the statistic. |
| `statistic_units` | string |  | `%`, `mm`, `cm²`, `kg`, `N·m` | Units of the estimate |
| `week` | integer |  |  | Study week of the reliability assessment |
| `testing_week_type` | string |  | vocabulary `testing_week_type` | When the reliability assessment took place. |
| `n` | integer |  | ≥ 1 | Participants in the reliability assessment. |
| `se_reli` | number |  | ≥ 0 | Standard error of the estimate. Reserved; not yet extracted. |
| `ci_level_reli` | number |  | ≥ 50, ≤ 99.9 | Confidence level (%). |
| `ci_low_reli` | number |  |  | Lower confidence limit. |
| `ci_high_reli` | number |  |  | Upper confidence limit. |

## Controlled vocabularies

Defined in `data/manual/vocabulary.csv`. Values are case-sensitive.

### `yes_no`

| Value | Description |
| :--- | :--- |
| `Yes` |  |
| `No` |  |

### `yes_no_unclear`

| Value | Description |
| :--- | :--- |
| `Yes` |  |
| `No` |  |
| `Unclear` | Not reported or ambiguous in the publication |

### `design`

| Value | Description |
| :--- | :--- |
| `Parallel Group` | Participants allocated to separate arms |
| `Within-Participant Unilateral` | Each participant trains limbs under different conditions |
| `Parallel Group + Within-Participant Unilateral` | Both parallel arms and within-participant limb conditions |
| `Within-Participant Crossover` | Each participant completes conditions sequentially |

### `testing_week_type`

| Value | Description |
| :--- | :--- |
| `Pre-Baseline` | Familiarization or reliability testing before baseline |
| `Baseline` | Baseline testing (defines week 0) |
| `Mid-Intervention` | Testing during the intervention |
| `Post-Intervention` | Testing at the end of the intervention |
| `Follow-Up` | Testing after a post-intervention period |
| `Reliability Testing` | Testing performed only to assess measurement reliability |
| `No Testing` | No testing this week |

### `training_week_type`

| Value | Description |
| :--- | :--- |
| `Training` | Intervention training |
| `Standardized Training` | Common training block preceding the intervention |
| `Reduced Training` | Reduced-volume or deload week |
| `No Training` | No training this week |
| `Non-Training Control` | Non-training control arm during the intervention period |

### `link_type`

| Value | Description |
| :--- | :--- |
| `Inter-Exercise` | Linked sets span different exercises (e.g. supersets) |
| `Intra-Exercise` | Linked sets within one exercise (e.g. cluster or rest-pause sets) |

### `implement`

| Value | Description |
| :--- | :--- |
| `Barbell` |  |
| `Dumbbell` |  |
| `Machine` |  |
| `Smith-Machine` |  |
| `Cable` |  |
| `Bodyweight` |  |
| `Kettlebell` |  |
| `Resistance Band` |  |
| `Isokinetic Dynamometer` |  |

### `pattern`

| Value | Description |
| :--- | :--- |
| `Bench Press` |  |
| `Chest Fly` |  |
| `Shoulder Press` |  |
| `Lateral Raise` |  |
| `Pulldown` |  |
| `Row` |  |
| `Elbow Flexion` |  |
| `Elbow Extension` |  |
| `Back Squat` |  |
| `Leg Press` |  |
| `Lunge` |  |
| `Deadlift` |  |
| `Hip Thrust` |  |
| `Knee Extension` |  |
| `Knee Flexion` |  |
| `Straight Leg Calf Raise` |  |

### `relative_load_type`

| Value | Description |
| :--- | :--- |
| `RM` | Load set to a repetition maximum (e.g. 8-12RM) |
| `%1RM` | Load as a percentage of one-repetition maximum |
| `%XRM` | Load as a percentage of a multi-repetition maximum |

### `ptf_type`

| Value | Description |
| :--- | :--- |
| `FAIL` | Sets taken to failure |
| `RM` | Sets taken to the prescribed repetition maximum |
| `RIR` | Sets stopped at a prescribed number of repetitions in reserve |
| `RPE` | Sets stopped at a prescribed rating of perceived exertion |

### `failure_definition`

| Value | Description |
| :--- | :--- |
| `Momentary Muscular Failure` |  |
| `Concentric Failure` |  |
| `Volitional Failure` |  |
| `Momentary Concentric Muscular Failure` |  |

### `domain`

| Value | Description |
| :--- | :--- |
| `Hypertrophy` | Muscle size |
| `Strength` | Maximal force or load |
| `Body Composition` | Whole-body or regional lean and fat mass |
| `Circumference` | Limb circumference |
| `Muscle Architecture` | Fascicle length and pennation |
| `Absolute Muscular Endurance` | Repetitions at a fixed absolute load |
| `Relative Muscular Endurance` | Repetitions at a load relative to current maximum |
| `RFD` | Rate of force development |

### `device`

| Value | Description |
| :--- | :--- |
| `B-mode US` | B-mode ultrasound |
| `MRI` | Magnetic resonance imaging |
| `CT` | Computed tomography |
| `DXA` | Dual-energy X-ray absorptiometry |
| `BIA` | Bioelectrical impedance analysis |
| `Muscle Biopsy` |  |
| `Tape Measure` |  |

### `device_value`

| Value | Description |
| :--- | :--- |
| `Muscle Thickness` |  |
| `Muscle Cross-Sectional Area` |  |
| `Type I Muscle Fiber Cross-Sectional Area` |  |
| `Type II Muscle Fiber Cross-Sectional Area` |  |
| `Lean Mass` |  |
| `Fat Mass` |  |
| `Circumference` |  |

### `muscle`

| Value | Description |
| :--- | :--- |
| `BBLH` | Biceps brachii long head |
| `BBSH` | Biceps brachii short head |
| `BRA` | Brachialis |
| `TBLH` | Triceps brachii long head |
| `TBLAT` | Triceps brachii lateral head |
| `TBMED` | Triceps brachii medial head |
| `RF` | Rectus femoris |
| `VL` | Vastus lateralis |
| `VI` | Vastus intermedius |
| `VM` | Vastus medialis |
| `GMH` | Gastrocnemius medial head |
| `GLH` | Gastrocnemius lateral head |
| `SOL` | Soleus |
| `PM` | Pectoralis major |

### `muscle_region`

| Value | Description |
| :--- | :--- |
| `Proximal` |  |
| `Middle` |  |
| `Distal` |  |

### `contraction_type`

| Value | Description |
| :--- | :--- |
| `Isotonic` |  |
| `Isometric` |  |
| `Isokinetic` |  |

### `measurement_units`

| Value | Description |
| :--- | :--- |
| `mm` |  |
| `cm` |  |
| `cm²` |  |
| `micrometers squared` |  |
| `kg` |  |
| `N·m` |  |
| `repetitions` |  |

### `statistic`

| Value | Description |
| :--- | :--- |
| `ICC` | Intraclass correlation coefficient |
| `CV` | Coefficient of variation |
| `SEM` | Standard error of measurement |
| `TE` | Typical error |
| `MDC` | Minimal detectable change |

### `statistic_units`

| Value | Description |
| :--- | :--- |
| `%` |  |
| `mm` |  |
| `cm²` |  |
| `kg` |  |
| `N·m` |  |

