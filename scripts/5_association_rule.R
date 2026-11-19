# ============================================================
# GROUP 7: MARKET BASKET ANALYSIS
# SCRIPT 5: ASSOCIATION RULE MINING
# ============================================================

# Note:
# Scripts 1 and 2 must be executed first.

library(arules)
library(arulesViz)

# 1. PREPARE OUTPUT DIRECTORY --------------------------------

dir.create("figures", showWarnings = FALSE)


# 2. REPRODUCIBLE SAMPLING -----------------------------------

set.seed(123)

sample_size <- 50000

all_order_ids <- unique(prior$order_id)

sample_order_ids <- sample(
  all_order_ids,
  size = min(sample_size, length(all_order_ids))
)

sample_prior <- prior[
  order_id %in% sample_order_ids,
  .(order_id, product_id)
]

cat("\nSAMPLED DATA DIMENSIONS\n")
print(dim(sample_prior))


# 3. MAP PRODUCT IDS TO PRODUCT NAMES ------------------------

product_lookup <- products[
  ,
  .(product_id, product_name)
]

sample_prior_named <- merge(
  sample_prior,
  product_lookup,
  by = "product_id",
  all.x = TRUE
)

sample_prior_named <- sample_prior_named[
  !is.na(product_name)
]


# 4. PREPARE TRANSACTIONS ------------------------------------

basket_list <- sample_prior_named[
  ,
  .(items = list(unique(product_name))),
  by = order_id
]

transactions <- as(
  setNames(basket_list$items, basket_list$order_id),
  "transactions"
)

cat("\nTRANSACTION SUMMARY\n")
print(summary(transactions))

stopifnot(length(transactions) > 0)


# 5. GENERATE ASSOCIATION RULES ------------------------------

rules <- apriori(
  transactions,
  parameter = list(
    support = 0.005,
    confidence = 0.20,
    minlen = 2,
    maxlen = 3
  )
)

cat("\nNUMBER OF ASSOCIATION RULES GENERATED:\n")
print(length(rules))

cat("\nASSOCIATION RULE SUMMARY\n")
print(summary(rules))


# 6. RANK RULES BY LIFT --------------------------------------

rules_by_lift <- sort(
  rules,
  by = "lift",
  decreasing = TRUE
)

cat("\nTOP 15 ASSOCIATION RULES BY LIFT\n")
inspect(head(rules_by_lift, 15))


# 7. EXPORT RULES AND METRICS --------------------------------

rules_table <- as(rules_by_lift, "data.frame")

rules_metrics <- as.data.table(
  quality(rules_by_lift)
)

rules_metrics[
  ,
  rule := labels(rules_by_lift)
]

setcolorder(
  rules_metrics,
  c("rule", setdiff(names(rules_metrics), "rule"))
)

cat("\nRULE METRICS SUMMARY\n")
print(summary(rules_metrics))

cat("\nMISSING VALUES IN RULE METRICS\n")
print(colSums(is.na(rules_metrics)))

fwrite(
  rules_table,
  "figures/association_rules.csv"
)

fwrite(
  rules_metrics,
  "figures/association_rules_metrics.csv"
)


# 8. VISUALISE TOP ASSOCIATION RULES -------------------------

top_rules <- head(rules_by_lift, 15)

png(
  "figures/association_rules_network.png",
  width = 1600,
  height = 1200,
  res = 150
)

plot(
  top_rules,
  method = "graph",
  engine = "igraph"
)

dev.off()


# 9. SAVE EXPERIMENT INFORMATION -----------------------------

experiment_summary <- data.table(
  sample_size = length(transactions),
  minimum_support = 0.005,
  minimum_confidence = 0.20,
  minimum_rule_length = 2,
  maximum_rule_length = 3,
  number_of_rules = length(rules)
)

fwrite(
  experiment_summary,
  "figures/association_experiment_summary.csv"
)

cat("\nAssociation rule mining completed successfully.\n")

# ============================================================
# END OF SCRIPT 5
# ============================================================