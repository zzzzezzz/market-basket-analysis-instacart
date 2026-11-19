
# ============================================================
# GROUP 7: MARKET BASKET ANALYSIS
# SCRIPT 1: PROJECT SETUP AND DATA LOADING
# ============================================================


# 1. PROJECT DIRECTORY ----------------------------------------

# Display current working directory
cat("Current working directory:", getwd(), "\n")

# Set project data directory
data_dir <- file.path(getwd(), "data")

# Check whether the data directory exists
if (!dir.exists(data_dir)) {
  stop(
    "Data directory not found. ",
    "Please set your working directory to the Group_7_Project folder."
  )
}


# 2. REQUIRED PACKAGES ----------------------------------------

required_packages <- c("data.table")

# Install packages that are not already installed
missing_packages <- required_packages[
  !required_packages %in% installed.packages()[, "Package"]
]

if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}

# Load required packages
library(data.table)


# 3. CHECK REQUIRED DATA FILES -------------------------------

required_files <- c(
  "orders.csv",
  "order_products__prior.csv",
  "order_products__train.csv",
  "products.csv",
  "aisles.csv",
  "departments.csv"
)

missing_files <- required_files[
  !file.exists(file.path(data_dir, required_files))
]

if (length(missing_files) > 0) {
  stop(
    "The following dataset files are missing from the data folder:\n",
    paste(missing_files, collapse = "\n"),
    "\nPlease download the Instacart dataset and place the files in the data folder."
  )
}

cat("All required dataset files found.\n")


# 4. LOAD DATASETS --------------------------------------------

cat("Loading datasets...\n")

orders <- fread(file.path(data_dir, "orders.csv"))

prior <- fread(file.path(data_dir, "order_products__prior.csv"))

train <- fread(file.path(data_dir, "order_products__train.csv"))

products <- fread(file.path(data_dir, "products.csv"))

aisles <- fread(file.path(data_dir, "aisles.csv"))

departments <- fread(file.path(data_dir, "departments.csv"))


# 5. DATASET DIMENSIONS ---------------------------------------

cat("\nDATASET DIMENSIONS\n")

cat("Orders:", nrow(orders), "rows |", ncol(orders), "columns\n")

cat("Prior:", nrow(prior), "rows |", ncol(prior), "columns\n")

cat("Train:", nrow(train), "rows |", ncol(train), "columns\n")

cat("Products:", nrow(products), "rows |", ncol(products), "columns\n")

cat("Aisles:", nrow(aisles), "rows |", ncol(aisles), "columns\n")

cat("Departments:", nrow(departments), "rows |", ncol(departments), "columns\n")


# 6. BASIC DATA VALIDATION ------------------------------------

stopifnot(
  all(c("order_id", "user_id", "eval_set") %in% names(orders)),
  all(c("order_id", "product_id", "reordered") %in% names(prior)),
  all(c("order_id", "product_id", "reordered") %in% names(train)),
  all(c("product_id", "aisle_id", "department_id") %in% names(products)),
  all(c("aisle_id", "aisle") %in% names(aisles)),
  all(c("department_id", "department") %in% names(departments))
)

cat("\nBasic dataset validation passed.\n")

cat("All six datasets loaded successfully.\n")

# ============================================================
# END OF SCRIPT 1
# ============================================================