# ============================================================
# GROUP 7: MARKET BASKET ANALYSIS
# SCRIPT 6: CUSTOMER SEGMENTATION
# ============================================================

# Note:
# Scripts 1 and 2 must be executed first.

library(data.table)
library(ggplot2)

dir.create("figures", showWarnings = FALSE)


# 1. CUSTOMER ORDER FREQUENCY -------------------------------

customer_frequency <- orders[
  ,
  .(total_orders = .N),
  by = user_id
]

cat("\nCUSTOMER ORDER FREQUENCY\n")
print(summary(customer_frequency$total_orders))


# 2. CUSTOMER BASKET SIZE -----------------------------------

order_baskets <- prior[
  ,
  .(basket_size = .N),
  by = order_id
]

order_baskets <- merge(
  order_baskets,
  orders[, .(order_id, user_id)],
  by = "order_id",
  all.x = TRUE
)

customer_basket <- order_baskets[
  ,
  .(
    average_basket_size = mean(basket_size),
    median_basket_size = median(basket_size)
  ),
  by = user_id
]

cat("\nCUSTOMER AVERAGE BASKET SIZE\n")
print(summary(customer_basket$average_basket_size))


# 3. CUSTOMER REORDER BEHAVIOUR -----------------------------

customer_reorder <- merge(
  prior,
  orders[, .(order_id, user_id)],
  by = "order_id",
  all.x = TRUE
)[
  ,
  .(
    total_product_lines = .N,
    reordered_lines = sum(reordered == 1),
    reorder_rate = mean(reordered == 1)
  ),
  by = user_id
]

cat("\nCUSTOMER REORDER RATE\n")
print(summary(customer_reorder$reorder_rate))


# 4. CUSTOMER ORDER INTERVALS -------------------------------

customer_intervals <- orders[
  !is.na(days_since_prior_order),
  .(
    average_order_interval = mean(days_since_prior_order),
    median_order_interval = median(days_since_prior_order)
  ),
  by = user_id
]

cat("\nAVERAGE CUSTOMER ORDER INTERVAL\n")
print(summary(customer_intervals$average_order_interval))


# 5. COMBINE CUSTOMER FEATURES ------------------------------

customer_features <- Reduce(
  function(x, y) {
    merge(x, y, by = "user_id", all = TRUE)
  },
  list(
    customer_frequency,
    customer_basket,
    customer_reorder,
    customer_intervals
  )
)

cat("\nCUSTOMER FEATURE TABLE\n")
print(dim(customer_features))

cat("\nMISSING VALUES\n")
print(colSums(is.na(customer_features)))


# 6. PREPARE DATA FOR CLUSTERING ----------------------------

clustering_data <- customer_features[
  ,
  .(
    total_orders,
    average_basket_size,
    reorder_rate,
    average_order_interval
  )
]

valid_rows <- complete.cases(clustering_data) &
  apply(
    as.matrix(clustering_data),
    1,
    function(x) all(is.finite(x))
  )

# Keep only customers with valid clustering features.
# This also preserves the correct customer-to-row alignment.

customer_features <- customer_features[valid_rows]
clustering_data <- clustering_data[valid_rows]

# Standardise features to comparable scales.
scaled_features <- scale(clustering_data)

cat("\nCLUSTERING DATA SUMMARY\n")
cat("Customers included:", nrow(scaled_features), "\n")
cat("Number of features:", ncol(scaled_features), "\n")

print(summary(scaled_features))

stopifnot(
  nrow(customer_features) == nrow(scaled_features),
  ncol(scaled_features) == 4
)


# 7. DETERMINE THE NUMBER OF CLUSTERS ------------------------

set.seed(123)

k_values <- 2:8

wss <- numeric(length(k_values))
iterations <- numeric(length(k_values))

for (i in seq_along(k_values)) {
  
  k <- k_values[i]
  
  model <- kmeans(
    scaled_features,
    centers = k,
    nstart = 10,
    iter.max = 500,
    algorithm = "Lloyd"
  )
  
  wss[i] <- model$tot.withinss
  iterations[i] <- model$iter
  
  cat(
    "Clusters:", k,
    "| Within-cluster variation:", round(wss[i], 2),
    "| Iterations:", model$iter,
    "\n"
  )
}


# 8. ELBOW METHOD VISUALISATION -----------------------------

elbow_data <- data.table(
  clusters = k_values,
  within_cluster_variation = wss,
  iterations = iterations
)

elbow_plot <- ggplot(
  elbow_data,
  aes(
    x = clusters,
    y = within_cluster_variation
  )
) +
  geom_line() +
  geom_point(size = 3) +
  scale_x_continuous(breaks = k_values) +
  labs(
    title = "Elbow Method for Customer Segmentation",
    subtitle = "Within-cluster variation across different cluster counts",
    x = "Number of Clusters (k)",
    y = "Total Within-Cluster Sum of Squares"
  ) +
  theme_minimal()

print(elbow_plot)

ggsave(
  "figures/customer_segmentation_elbow.png",
  plot = elbow_plot,
  width = 9,
  height = 6,
  dpi = 300
)

fwrite(
  elbow_data,
  "figures/customer_segmentation_elbow.csv"
)


# 9. FINAL K-MEANS MODEL ------------------------------------

# Four clusters are selected based on the elbow analysis
# and the interpretability of the resulting customer groups.

set.seed(123)

final_kmeans <- kmeans(
  scaled_features,
  centers = 4,
  nstart = 20,
  iter.max = 500,
  algorithm = "Lloyd"
)

# Assign cluster labels to the matching customer records.

customer_features[
  ,
  cluster := factor(final_kmeans$cluster)
]

stopifnot(
  nrow(customer_features) == length(final_kmeans$cluster)
)


# 10. CUSTOMER CLUSTER SIZES --------------------------------

cluster_sizes <- customer_features[
  ,
  .(
    number_of_customers = .N,
    percentage = round(
      .N / nrow(customer_features) * 100,
      2
    )
  ),
  by = cluster
]

cat("\nCUSTOMER DISTRIBUTION BY CLUSTER\n")
print(cluster_sizes)


# 11. CUSTOMER CLUSTER PROFILES -----------------------------

cluster_profile <- customer_features[
  ,
  .(
    customers = .N,
    average_orders = mean(total_orders),
    median_orders = median(total_orders),
    average_basket_size = mean(average_basket_size),
    average_reorder_rate = mean(reorder_rate),
    average_order_interval = mean(average_order_interval),
    median_order_interval = median(average_order_interval)
  ),
  by = cluster
]

cat("\nCUSTOMER SEGMENTATION PROFILES\n")
print(cluster_profile)


# 12. VISUALISE CUSTOMER SEGMENTS ---------------------------

cluster_plot <- ggplot(
  cluster_profile,
  aes(
    x = average_orders,
    y = average_basket_size,
    size = customers,
    label = cluster
  )
) +
  geom_point(alpha = 0.7) +
  geom_text(nudge_y = 0.4, show.legend = FALSE) +
  labs(
    title = "Customer Segmentation Using K-Means",
    subtitle = "Four groups based on customer ordering behaviour",
    x = "Average Number of Orders",
    y = "Average Basket Size",
    size = "Number of Customers"
  ) +
  theme_minimal()

print(cluster_plot)

ggsave(
  "figures/customer_segmentation_clusters.png",
  plot = cluster_plot,
  width = 9,
  height = 6,
  dpi = 300
)


# 13. EXPORT RESULTS ----------------------------------------

fwrite(
  cluster_profile,
  "figures/customer_cluster_profiles.csv"
)

fwrite(
  cluster_sizes,
  "figures/customer_cluster_sizes.csv"
)

fwrite(
  customer_features,
  "figures/customer_cluster_assignments.csv"
)

cat("\nCustomer segmentation completed successfully.\n")

# ============================================================
# END OF SCRIPT 6
# ============================================================