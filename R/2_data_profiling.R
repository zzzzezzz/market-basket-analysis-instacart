# ============================================================
# GROUP 7: MARKET BASKET ANALYSIS
# SCRIPT 2: DATA PROFILING
# ============================================================

# Note:
# Script 1 must be executed first.
# The datasets are already loaded into memory.

# 1. DATASET DIMENSIONS ---------------------------------------

cat("\nDATASET DIMENSIONS\n")

dataset_dimensions <- data.table(
  Dataset = c(
    "Orders",
    "Prior order products",
    "Training order products",
    "Products",
    "Aisles",
    "Departments"
  ),
  Rows = c(
    nrow(orders),
    nrow(prior),
    nrow(train),
    nrow(products),
    nrow(aisles),
    nrow(departments)
  ),
  Columns = c(
    ncol(orders),
    ncol(prior),
    ncol(train),
    ncol(products),
    ncol(aisles),
    ncol(departments)
  )
)

print(dataset_dimensions)


# 2. DATASET STRUCTURE ---------------------------------------

cat("\nORDERS STRUCTURE\n")
str(orders)

cat("\nPRIOR ORDER PRODUCTS STRUCTURE\n")
str(prior)

cat("\nTRAINING ORDER PRODUCTS STRUCTURE\n")
str(train)

cat("\nPRODUCTS STRUCTURE\n")
str(products)


# 3. SAMPLE RECORDS ------------------------------------------

cat("\nSAMPLE HISTORICAL ORDER RECORDS\n")
print(head(prior))

cat("\nSAMPLE TRAINING ORDER RECORDS\n")
print(head(train))


# 4. MISSING VALUE ANALYSIS ----------------------------------

cat("\nMISSING VALUES BY DATASET\n")

missing_values <- data.table(
  Dataset = c(
    "Orders",
    "Prior",
    "Train",
    "Products",
    "Aisles",
    "Departments"
  ),
  Missing_Values = c(
    sum(is.na(orders)),
    sum(is.na(prior)),
    sum(is.na(train)),
    sum(is.na(products)),
    sum(is.na(aisles)),
    sum(is.na(departments))
  )
)

print(missing_values)


# 5. DUPLICATE IDENTIFIER CHECKS -----------------------------

cat("\nDUPLICATE ORDER IDENTIFIERS\n")

duplicate_orders <- orders[
  ,
  .N,
  by = order_id
][N > 1]

print(duplicate_orders)

cat("\nDUPLICATE PRODUCT IDENTIFIERS\n")

duplicate_products <- products[
  ,
  .N,
  by = product_id
][N > 1]

print(duplicate_products)


# 6. DATASET UNIQUENESS --------------------------------------

cat("\nDATASET UNIQUENESS\n")

cat("Unique customers:", uniqueN(orders$user_id), "\n")

cat("Unique purchased products:", uniqueN(prior$product_id), "\n")

cat("Unique historical orders:", uniqueN(prior$order_id), "\n")


# 7. REORDER DISTRIBUTION ------------------------------------

cat("\nREORDER DISTRIBUTION\n")

reorder_distribution <- prior[
  ,
  .N,
  by = reordered
][order(reordered)]

print(reorder_distribution)


# 8. OVERALL REORDER STATISTICS ------------------------------

reorder_summary <- prior[
  ,
  .(
    total_order_lines = .N,
    reorder_lines = sum(reordered == 1),
    reorder_percentage = mean(reordered == 1) * 100
  )
]

cat("\nOVERALL REORDER SUMMARY\n")
print(reorder_summary)


# ============================================================
# END OF SCRIPT 2
# ============================================================