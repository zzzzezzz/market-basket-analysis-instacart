# ============================================================
# GROUP 7: MARKET BASKET ANALYSIS
# MASTER SCRIPT - RUN THE COMPLETE PROJECT
# ============================================================
#
# EXPECTED PROJECT STRUCTURE
#
# group 7/
# |-- Group7_instacart_project.Rproj
# |-- run_all.R
# |-- data/
# |   |-- orders.csv
# |   |-- order_products__prior.csv
# |   |-- order_products__train.csv
# |   |-- products.csv
# |   |-- aisles.csv
# |   `-- departments.csv
# |-- scripts/
# |   |-- 1_setup.R
# |   |-- 2_data_profiling.R
# |   |-- 3_ordering_patterns.R
# |   |-- 4_product_analysis.R
# |   |-- 5_association_rule.R
# |   |-- 6_customer_segmentation.R
# |   `-- 7_reorder_prediction.R
# |-- figures/
# |-- results/
# `-- report/
#
# HOW TO RUN
# 1. Open Group7_instacart_project.Rproj in RStudio.
# 2. Open this run_all.R file.
# 3. Click the Source button (not Run).
#
# The scripts are sourced in order into the global environment.
# This is necessary because scripts 2-6 use objects loaded by
# script 1. The working directory remains the project root.
# ============================================================


# 0. START ----------------------------------------------------

cat("\n")
cat("============================================================\n")
cat("GROUP 7: MARKET BASKET ANALYSIS\n")
cat("MASTER WORKFLOW\n")
cat("============================================================\n")
cat("Working directory: ", getwd(), "\n", sep = "")
cat("Started: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n", sep = "")


# 1. LOCATE AND VALIDATE PROJECT ------------------------------

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

# This master script is designed to be run from the project root.
# If RStudio is currently pointing to the scripts folder, use its
# parent as the project root.
if (basename(project_root) == "scripts" &&
    dir.exists(file.path(project_root, "..", "data"))) {
  project_root <- normalizePath(
    file.path(project_root, ".."),
    winslash = "/",
    mustWork = TRUE
  )
  setwd(project_root)
}

script_dir <- file.path(project_root, "scripts")
data_dir <- file.path(project_root, "data")

if (!dir.exists(script_dir)) {
  stop(
    "\nCannot find the 'scripts' folder.\n",
    "Expected location: ", script_dir, "\n\n",
    "Open Group7_instacart_project.Rproj in RStudio, then run this file."
  )
}

if (!dir.exists(data_dir)) {
  stop(
    "\nCannot find the 'data' folder.\n",
    "Expected location: ", data_dir
  )
}

script_files <- c(
  "1_setup.R",
  "2_data_profiling.R",
  "3_ordering_patterns.R",
  "4_product_analysis.R",
  "5_association_rule.R",
  "6_customer_segmentation.R",
  "7_reorder_prediction.R"
)

script_paths <- file.path(script_dir, script_files)
missing_scripts <- script_files[!file.exists(script_paths)]

if (length(missing_scripts) > 0) {
  stop(
    "\nThe following scripts are missing from the scripts folder:\n",
    paste0(" - ", missing_scripts, collapse = "\n"),
    "\n\nCheck the filenames in: ", script_dir
  )
}

required_data_files <- c(
  "orders.csv",
  "order_products__prior.csv",
  "order_products__train.csv",
  "products.csv",
  "aisles.csv",
  "departments.csv"
)

missing_data <- required_data_files[
  !file.exists(file.path(data_dir, required_data_files))
]

if (length(missing_data) > 0) {
  stop(
    "\nThe following required dataset files are missing from data/:\n",
    paste0(" - ", missing_data, collapse = "\n"),
    "\n\nPlace all six Instacart CSV files in: ", data_dir
  )
}

cat("Project structure check: PASSED\n")
cat("All seven analysis scripts found.\n")
cat("All six required CSV files found.\n\n")


# 2. CHECK REQUIRED R PACKAGES -------------------------------

required_packages <- c(
  "data.table",
  "ggplot2",
  "arules",
  "arulesViz",
  "xgboost",
  "pROC"
)

installed_packages <- rownames(installed.packages())
packages_to_install <- setdiff(required_packages, installed_packages)

if (length(packages_to_install) > 0) {
  cat("Installing missing packages:\n")
  cat(paste(packages_to_install, collapse = ", "), "\n\n")

  install.packages(
    packages_to_install,
    repos = "https://cloud.r-project.org"
  )
}

package_available <- vapply(
  required_packages,
  requireNamespace,
  logical(1),
  quietly = TRUE
)

if (!all(package_available)) {
  stop(
    "\nCould not load these required packages:\n",
    paste(required_packages[!package_available], collapse = ", "),
    "\nInstall them manually and run the master script again."
  )
}

cat("Required package check: PASSED\n\n")


# 3. PREPARE OUTPUT FOLDERS ----------------------------------

dir.create(file.path(project_root, "figures"),
           showWarnings = FALSE, recursive = TRUE)

dir.create(file.path(project_root, "results"),
           showWarnings = FALSE, recursive = TRUE)

dir.create(file.path(project_root, "report"),
           showWarnings = FALSE, recursive = TRUE)


# 4. RUN THE SEVEN SCRIPTS IN SEQUENCE -----------------------

run_log <- data.frame(
  script = character(),
  status = character(),
  minutes = numeric(),
  stringsAsFactors = FALSE
)

for (i in seq_along(script_paths)) {

  script_name <- script_files[i]
  script_path <- script_paths[i]

  cat("\n")
  cat("------------------------------------------------------------\n")
  cat("STEP ", i, " OF ", length(script_paths), ": ", script_name, "\n",
      sep = "")
  cat("Started: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
  cat("------------------------------------------------------------\n")

  start_time <- Sys.time()

  tryCatch(
    {
      # Use .GlobalEnv so data objects and results created by each
      # script remain available to the following scripts.
      source(
        script_path,
        local = .GlobalEnv,
        echo = FALSE,
        chdir = FALSE
      )

      elapsed_minutes <- as.numeric(
        difftime(Sys.time(), start_time, units = "mins")
      )

      run_log <- rbind(
        run_log,
        data.frame(
          script = script_name,
          status = "COMPLETED",
          minutes = round(elapsed_minutes, 2),
          stringsAsFactors = FALSE
        )
      )

      cat("\n", script_name, " COMPLETED in ",
          round(elapsed_minutes, 2), " minutes.\n", sep = "")
    },
    error = function(e) {
      elapsed_minutes <- as.numeric(
        difftime(Sys.time(), start_time, units = "mins")
      )

      run_log <<- rbind(
        run_log,
        data.frame(
          script = script_name,
          status = "FAILED",
          minutes = round(elapsed_minutes, 2),
          stringsAsFactors = FALSE
        )
      )

      # Save the progress log so the point of failure is recorded.
      write.csv(
        run_log,
        file.path(project_root, "results", "master_run_log.csv"),
        row.names = FALSE
      )

      stop(
        "\nMASTER WORKFLOW STOPPED.\n",
        "Script that failed: ", script_name, "\n",
        "Error message: ", conditionMessage(e), "\n\n",
        "Completed scripts and timings have been saved to ",
        "results/master_run_log.csv.\n",
        "Fix the error above, then run the master script again.",
        call. = FALSE
      )
    }
  )
}


# 5. SAVE FINAL EXECUTION LOG -------------------------------

write.csv(
  run_log,
  file.path(project_root, "results", "master_run_log.csv"),
  row.names = FALSE
)


# 6. FINAL SUMMARY -------------------------------------------

cat("\n\n")
cat("============================================================\n")
cat("ALL SEVEN PROJECT SCRIPTS COMPLETED SUCCESSFULLY\n")
cat("============================================================\n")
print(run_log)
cat("\nFinished: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
cat("Execution log: results/master_run_log.csv\n")
cat("Generated outputs: figures/ and results/\n")
cat("============================================================\n")
