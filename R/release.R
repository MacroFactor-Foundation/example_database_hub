# Public assets for a dataset-snapshot release (AGENTS.md "Prepare and
# publish a stage release", step 8). For a tag data-vX.Y.Z this writes:
#
#   <repo>-<tag>-data.zip   data/, config/schema.yml, data/README.md, LICENSE-DATA.md
#   SHA256SUMS              sha256sum-format checksums of every bundled file and the zip
#   release-manifest.json   tag, commit, per-table rows/bytes/SHA-256, tool versions,
#                           renv.lock checksum and build date
#
# Spokes copy the per-table checksums into their config/data-manifest.yml and
# verify them after checking out the tag.

release_bundle_files <- function(schema) {
  unname(c(
    hub_data_paths(schema, root = "."),
    "config/schema.yml", "data/README.md", "LICENSE-DATA.md"
  ))
}

build_release_assets <- function(tag, commit, out_dir, root = ".", repository, build_date = Sys.Date()) {
  if (!grepl("^data-v[0-9]+\\.[0-9]+\\.[0-9]+$", tag)) {
    stop("Dataset tags must look like data-vMAJOR.MINOR.PATCH, not '", tag, "'.", call. = FALSE)
  }
  schema <- read_schema(file.path(root, "config", "schema.yml"))
  raw <- read_hub_raw(schema, root)
  assert_valid_hub(validate_hub(raw, schema))

  rel <- sub("^\\./", "", release_bundle_files(schema))
  abs <- file.path(root, rel)
  missing <- rel[!file.exists(abs)]
  if (length(missing)) stop("Release files missing: ", paste(missing, collapse = ", "), call. = FALSE)

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  bundle_name <- paste0(basename(repository), "-", tag, "-data.zip")
  bundle <- file.path(out_dir, bundle_name)
  unlink(bundle)
  zip::zip(bundle, files = rel, root = root, mode = "mirror")

  sha <- function(paths) unname(tools::sha256sum(paths))
  file_sha <- sha(abs)
  bundle_sha <- sha(bundle)

  sums <- c(paste0(file_sha, "  ", rel), paste0(bundle_sha, "  ", bundle_name))
  write_lines_atomic(sums, file.path(out_dir, "SHA256SUMS"))

  table_entry <- function(name) {
    path <- schema$tables[[name]]$file
    list(
      table = name, path = path,
      rows = nrow(raw$tables[[name]]),
      bytes = file.size(file.path(root, path)),
      sha256 = file_sha[match(path, rel)]
    )
  }
  lock <- file.path(root, "renv.lock")
  manifest <- list(
    object = "dataset_snapshot",
    tag = tag,
    commit = commit,
    repository = repository,
    build_date = format(build_date),
    data_status = "synthetic",
    schema_version = schema$schema_version,
    tables = unname(lapply(names(schema$tables), table_entry)),
    other_files = unname(lapply(setdiff(rel, vapply(schema$tables, `[[`, "", "file")), function(p) {
      list(path = p, bytes = file.size(file.path(root, p)), sha256 = file_sha[match(p, rel)])
    })),
    bundle = list(file = bundle_name, bytes = file.size(bundle), sha256 = bundle_sha),
    build_tools = list(
      r = R.version.string,
      renv = as.character(utils::packageVersion("renv")),
      renv_lock_sha256 = if (file.exists(lock)) sha(lock) else NULL
    ),
    data_manifest_sha256 = NULL # not applicable: a hub has no external data manifest
  )
  manifest_path <- file.path(out_dir, "release-manifest.json")
  write_lines_atomic(jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA), manifest_path)

  c(bundle = bundle, sums = file.path(out_dir, "SHA256SUMS"), manifest = manifest_path)
}
