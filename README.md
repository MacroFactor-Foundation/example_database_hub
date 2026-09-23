<picture>
  <source media="(prefers-color-scheme: dark)" srcset="site/assets/logos/wordmark-white.png">
  <img src="site/assets/logos/wordmark-black.png" alt="MacroFactor Foundation" height="48">
</picture>

# Example Database Hub

> **Example repository with synthetic data.** Every study, author, DOI and value in `data/` is
> invented (see [`data-raw/generate_toy_data.R`](data-raw/generate_toy_data.R)). This repository
> shows the team the structure and workflow of a *hub* in the living-database pattern. It holds no
> real evidence.

## What this repository is

This is a **hub**: a corpus of data extracted from studies, stored as plain CSV files in Git.
Separate **spoke** repositories (systematic reviews, standalone papers, tools) read from it.
Each spoke is pinned to a fixed data tag or commit, never to the live `main` branch.

This hub is **data + analysis + site**. As well as the data, it runs its own `targets`
pipeline to answer the project's primary questions and publishes the results as a Quarto site
on GitHub Pages.

| Part | Where | What it does |
|---|---|---|
| Data | `data/*.csv`, `data/manual/vocabulary.csv` | One CSV per normalized entity, joined by stable IDs. |
| Schema | `config/schema.yml` | The single source of truth for tables, columns, types, keys and rules. |
| Data dictionary | `data/README.md` | Generated from the schema. |
| Validation | `R/validate.R`, `scripts/validate_data.R` | Checks the data against the schema on every pull request. |
| Analyses | `R/analysis.R`, `R/figures.R`, `_targets.R` | Effect sizes, meta-analyses, figures, visualiser plots. |
| Site interface | `site/_variables.yml`, `site/generated/` | Pipeline outputs, committed, so the site renders from a fresh clone. |
| Site | `site/*.qmd` | Overview, data visualiser, analyses, data dictionary, pinning guide. |
| Release ledger | `config/releases.yml` | Dataset-snapshot and site-deployment tags. |

**Deliberately absent:**
- `config/data-manifest.yml`: in a hub the data are the repository itself, not an external
  dependency. Spokes use that file to pin *this* hub.
- `manuscript/`: a paper built on the hub gets its own spoke repository.

## The data

Eight tables: `study`, `arm`, `arm_week`, `training_set`, `measure`, `outcome`, `contrast` and
`reliability`, plus controlled vocabularies. See [`data/README.md`](data/README.md) for every
table, column, key and rule. In brief:

- **IDs are stable and never reused or renumbered.** For example, `study_id` = first-author
  surname + year + letter (`hartley2019a`); `arm_id` = `study_id` + `_` + arm label
  (`hartley2019a_hl`); `measure_id` = `study_id` + `_m01`, and so on.
- **Empty field = missing.** The literal text `NA` is a value and fails vocabulary checks.
- **Ranges are split into typed columns**, e.g. `reps_min`/`reps_max`. Tempo is split into
  `tempo_eccentric`/`tempo_pause`/`tempo_concentric`.
- Descriptive fields that the workbook repeated on every sheet (the study citation, and each
  measure's device, muscle and units) are stored once, in `study` and `measure`.

## Using the hub from a spoke

In the spoke's `config/data-manifest.yml`, pin to an **immutable data tag** (or a full commit
SHA, never a branch name) and record a SHA-256 checksum for each table you read:

```yaml
external_sources:
  example_database_hub:
    repo: https://github.com/MacroFactor-Foundation/example_database_hub
    ref: data-v1.0.0
    ref_type: tag
    fetched_at: 2026-09-23
    tables:
      - path: data/study.csv
        sha256: <checksum>
```

The spoke's first pipeline target checks out exactly that ref and verifies the checksums.
Moving the pin is a deliberate, documented change.

Data tags follow `data-vMAJOR.MINOR.PATCH`:
- MAJOR: breaking schema change.
- MINOR: data or columns added.
- PATCH: corrections to existing values.

Site deployments are tagged `site-vMAJOR.MINOR.PATCH`. All tags are recorded in
[`config/releases.yml`](config/releases.yml) and are never moved or reused.

## Contributing data

1. Branch from `main` and add or correct rows in the CSVs. Assign new IDs; never renumber
   existing ones. Spreadsheet editing is fine, but save as UTF-8 CSV, never `.xlsx`.
2. Changing the schema? Edit `config/schema.yml`, then run
   `Rscript scripts/build_data_dictionary.R`.
3. Run `Rscript scripts/validate_data.R`. It lists every problem with its CSV line number.
4. Open a pull request. The **Validate data** workflow reruns the validation and the test suite,
   and annotates failing rows.

## Reproducing the analyses and site

**Requirements:**
- R 4.6.1 (recorded in `renv.lock`).
- Quarto ≥ 1.9 (CI pins 1.9.38).
- Git.
- On Linux, the system libraries listed in `.github/workflows/validate-data.yml` (e.g.
  `libglpk-dev` for igraph); `renv::restore()` reports any that are missing.
- On Windows, [Rtools](https://cran.r-project.org/bin/windows/Rtools/) matching your R version,
  for the occasional package that has no pre-built binary.
- Optional: the [DM Sans](https://fonts.google.com/specimen/DM+Sans) font installed locally,
  for exact label spacing in the figures. The site loads it as a web font either way.

From a fresh clone:

```r
renv::restore()          # install the exact package versions
targets::tar_make()      # validate data, run analyses, write site/_variables.yml and site/generated/
```

```bash
quarto preview site      # or: quarto render site  (output in site/_site/, not committed)
```

The site needs only Quarto and the committed `site/` folder; it never reads `_targets/`.
After a data or analysis change, run the pipeline, review the diff of `site/generated/` and
`site/_variables.yml`, and commit them with the change.

Checks that are safe to run at any time:

```bash
Rscript scripts/validate_data.R
Rscript tests/testthat.R
Rscript -e 'targets::tar_validate()'
```

## Repository layout

```text
.github/workflows/  validate-data.yml (every PR), build-deploy-site.yml (site-v* tags)
config/             schema.yml, project.yml (analysis settings), releases.yml (release ledger)
data/               the tables, data/manual/vocabulary.csv, README.md (generated dictionary)
data-raw/           generate_toy_data.R (example only: builds the synthetic data)
R/                  hub_data.R, validate.R, analysis.R, figures.R, site_outputs.R
scripts/            validate_data.R, build_data_dictionary.R
site/               Quarto website; generated/ and _variables.yml are pipeline-owned;
                    assets/logos/ holds the official brand marks (web-sized copies)
tests/testthat/     validator, dictionary and analysis tests
_targets.R          the pipeline
```

## Licence and citation

- **Code** (`R/`, `scripts/`, `data-raw/`, `tests/`, `_targets.R`, workflows, site scripts and
  theme): [MIT](LICENSE).
- **Data** (`data/`) **and site content** (`site/` pages, generated figures and tables):
  [CC BY 4.0](LICENSE-DATA.md).
- MacroFactor brand marks (including `site/assets/logos/`) are not covered by either licence.

Citation metadata is in [`CITATION.cff`](CITATION.cff). Cite the specific data tag you used.
