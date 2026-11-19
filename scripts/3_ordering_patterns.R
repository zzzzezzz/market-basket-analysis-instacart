# ============================================================
# GROUP 7: MARKET BASKET ANALYSIS
# SCRIPT 3: ORDERING PATTERNS AND BASKET SIZE
# ============================================================

# Note:
# Scripts 1 and 2 must be executed first.

# 1. PREPARE OUTPUT DIRECTORY --------------------------------
library(ggplot2)

dir.create("figures", showWarnings = FALSE)


# 2. ORDERING ACTIVITY BY WEEKDAY AND HOUR --------------------

orders_by_time <- orders[
  ,
  .(number_of_orders = .N),
  by = .(order_dow, order_hour_of_day)
]

setorder(orders_by_time, order_dow, order_hour_of_day)

cat("\nORDERING ACTIVITY BY WEEKDAY AND HOUR\n")
print(head(orders_by_time))

cat("Number of weekday-hour combinations:", nrow(orders_by_time), "\n")


# 3. CREATE WEEKDAY-HOUR HEATMAP -----------------------------

# Instacart weekday numbering:
# 0 = Sunday, 1 = Monday, ..., 6 = Saturday

weekday_labels <- c(
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday"
)

orders_by_time[
  ,
  weekday := factor(
    order_dow,
    levels = 0:6,
    labels = weekday_labels
  )
]

time_heatmap <- ggplot(
  orders_by_time,
  aes(
    x = order_hour_of_day,
    y = weekday,
    fill = number_of_orders
  )
) +
  geom_tile(color = "white", linewidth = 0.2) +
  scale_x_continuous(breaks = 0:23) +
  scale_fill_viridis_c(
    option = "C",
    trans = "sqrt",
    name = "Number of Orders"
  ) +
  labs(
    title = "Instacart Ordering Activity by Weekday and Hour",
    subtitle = "Square-root colour scaling highlights differences in order volume",
    x = "Hour of Day",
    y = "Day of Week"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold"),
    panel.grid = element_blank()
  )

print(time_heatmap)

ggsave(
  filename = "figures/ordering_heatmap.png",
  plot = time_heatmap,
  width = 12,
  height = 7,
  dpi = 300
)


# 4. CALCULATE BASKET SIZE -----------------------------------

basket_sizes <- prior[
  ,
  .(basket_size = .N),
  by = order_id
]

cat("\nBASKET SIZE SUMMARY\n")

basket_summary <- basket_sizes[
  ,
  .(
    number_of_orders = .N,
    average_basket_size = mean(basket_size),
    median_basket_size = median(basket_size),
    smallest_basket = min(basket_size),
    largest_basket = max(basket_size)
  )
]

print(basket_summary)


# 5. VISUALISE BASKET SIZE DISTRIBUTION ----------------------

basket_plot <- ggplot(
  basket_sizes,
  aes(x = basket_size)
) +
  geom_histogram(
    binwidth = 1,
    fill = "steelblue",
    color = "white"
  ) +
  labs(
    title = "Distribution of Instacart Basket Sizes",
    subtitle = "Number of products purchased per historical order",
    x = "Number of Products in Basket",
    y = "Number of Orders"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold")
  )

print(basket_plot)

ggsave(
  filename = "figures/basket_size_distribution.png",
  plot = basket_plot,
  width = 10,
  height = 6,
  dpi = 300
)


# 6. SAVE ANALYSIS RESULTS -----------------------------------

fwrite(
  orders_by_time,
  "figures/orders_by_time.csv"
)

fwrite(
  basket_sizes,
  "figures/basket_sizes.csv"
)

fwrite(
  basket_summary,
  "figures/basket_summary.csv"
)

cat("\nOrdering pattern and basket-size analysis completed.\n")

# ============================================================
# END OF SCRIPT 3
# ============================================================