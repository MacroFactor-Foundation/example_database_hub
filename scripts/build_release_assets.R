# Build the public assets for a dataset-snapshot release from the exact
# tagged commit. Run from the project root on a clean checkout of the tag:
#
#   Rscript scripts/build_release_assets.R data-v1.0.0
#
# Refuses to run if the working tree has changes or HEAD is not the tagged
# commit, so the assets always describe exactly what the tag contains.
# Output: outputs/release/<tag>/ (ignored by Git; attach its files to the
# GitHub release).

source("R/hub_data.R")
source("R/validate.R")
source("R/site_outputs.R")
source("R/release.R")

tag <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(tag)) stop("Usage: Rscript scripts/build_release_assets.R data-vX.Y.Z", call. = FALSE)

git <- function(...) {
  out <- suppressWarnings(system2("git", c(...), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) stop("git ", paste(...), " failed: ", paste(out, collapse = " "), call. = FALSE)
  out
}

dirty <- git("status", "--porcelain", "--untracked-files=no")
if (length(dirty)) stop("Working tree has uncommitted changes; build release assets from a clean checkout.", call. = FALSE)
head <- git("rev-parse", "HEAD")
tagged <- git("rev-parse", paste0(tag, "^{commit}"))
if (!identical(head, tagged)) stop("HEAD (", head, ") is not the commit tagged ", tag, " (", tagged, ").", call. = FALSE)

project <- read_project_config("config/project.yml")
paths <- build_release_assets(
  tag = tag, commit = head,
  out_dir = file.path("outputs", "release", tag),
  repository = project$project$repository
)
message("Release assets for ", tag, " (", substr(head, 1, 7), "):\n", paste0("  ", paths, collapse = "\n"))
