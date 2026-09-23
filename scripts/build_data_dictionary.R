# Regenerate data/README.md from config/schema.yml and the vocabulary file.
# Run from the project root after any schema or vocabulary change:
#
#   Rscript scripts/build_data_dictionary.R

source("R/hub_data.R")
source("R/site_outputs.R")

schema <- read_schema("config/schema.yml")
vocabulary <- read_csv_character(schema$vocabulary_file)
invisible(write_lines_atomic(build_data_readme(schema, vocabulary), "data/README.md"))
message("Wrote data/README.md")
