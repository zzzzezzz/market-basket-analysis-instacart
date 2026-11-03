# ============================================================
# GROUP 7: MARKET BASKET ANALYSIS
# SCRIPT 4: PRODUCT AND DEPARTMENT ANALYSIS
# ============================================================

# Note:
# Scripts 1, 2 and 3 must be executed first.

library(ggplot2)

# 1. PREPARE OUTPUT DIRECTORY --------------------------------

dir.create("figures", showWarnings = FALSE)


# 2. COUNT PRODUCT PURCHASES ---------------------------------

product_counts <- prior[
  ,
  .(purchase_count = .N),
  by = product_id
]

setorder(product_counts, -purchase_count)


# 3. ATTACH PRODUCT AND DEPARTMENT INFORMATION ---------------

product_details <- merge(
  product_counts,
  products[, .(product_id, product_name, department_id)],
  by = "product_id",
  all.x = TRUE
)

product_details <- merge(
  product_details,
  departments,
  by = "department_id",
  all.x = TRUE
)

setorder(product_details, -purchase_count)


# 4. DISPLAY TOP 15 PRODUCTS ---------------------------------

cat("\nTOP 15 MOST FREQUENTLY PURCHASED PRODUCTS\n")

top_products <- product_details[
  1:15,
  .(product_name, department, purchase_count)
]

print(top_products)


# 5. DEPARTMENT PURCHASE SUMMARY -----------------------------

department_summary <- product_details[
  ,
  .(
    total_product_lines = sum(purchase_count),
    number_of_products = uniqueN(product_id)
  ),
  by = department
]

setorder(department_summary, -total_product_lines)

cat("\nPURCHASE FREQUENCY BY DEPARTMENT\n")
print(department_summary)


# 6. VISUALISE DEPARTMENT PURCHASES --------------------------

department_plot <- ggplot(
  department_summary,
  aes(
    x = reorder(department, total_product_lines),
    y = total_product_lines
  )
) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Product Purchase Frequency by Department",
    subtitle = "Based on product lines in prior orders",
    x = "Department",
    y = "Number of Product Lines"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold")
  )

print(department_plot)

ggsave(
  filename = "figures/purchases_by_department.png",
  plot = department_plot,
  width = 10,
  height = 8,
  dpi = 300
)


# 7. SAVE ANALYSIS RESULTS -----------------------------------

fwrite(
  top_products,
  "figures/top_15_products.csv"
)

fwrite(
  department_summary,
  "figures/department_summary.csv"
)

fwrite(
  product_details,
  "figures/product_details.csv"
)

cat("\nProduct and department analysis completed.\n")

# ============================================================
# END OF SCRIPT 4
# ============================================================