# ============================================================
# GROUP 7: MARKET BASKET ANALYSIS
# SCRIPT 07: PRODUCT REORDER PREDICTION
# ============================================================

library(data.table)
library(xgboost)
library(pROC)

set.seed(123)

dir.create("figures", showWarnings = FALSE)


# 1. DATA LOADING AND VALIDATION -----------------------------

required_objects <- c("orders", "prior", "train", "products")

missing_objects <- required_objects[
  !vapply(required_objects, exists, logical(1))
]

if (length(missing_objects) > 0) {
  
  required_files <- c(
    "orders.csv",
    "order_products__prior.csv",
    "order_products__train.csv",
    "products.csv"
  )
  
  missing_files <- required_files[
    !file.exists(file.path("data", required_files))
  ]
  
  if (length(missing_files) > 0) {
    stop(
      "Missing dataset files: ",
      paste(missing_files, collapse = ", "),
      ". Run Script 1 or check your data folder."
    )
  }
  
  orders <- fread("data/orders.csv")
  prior <- fread("data/order_products__prior.csv")
  train <- fread("data/order_products__train.csv")
  products <- fread("data/products.csv")
}

setDT(orders)
setDT(prior)
setDT(train)
setDT(products)

cat("\nDATASET DIMENSIONS\n")
cat("Orders:", nrow(orders), "\n")
cat("Prior product records:", nrow(prior), "\n")
cat("Training product records:", nrow(train), "\n")
cat("Products:", nrow(products), "\n")


# 2. FEATURE ENGINEERING AND TARGET LABELING ---------------

cat("\nBUILDING CUSTOMER-PRODUCT FEATURES...\n")

train_users <- unique(
  orders[eval_set == "train", user_id]
)

# Historical orders belonging to customers with a
# labelled training order.

prior_order_map <- orders[
  eval_set == "prior" & user_id %in% train_users,
  .(order_id, user_id, order_number)
]

prior_history <- merge(
  prior,
  prior_order_map,
  by = "order_id",
  all = FALSE
)

# Build one row for each customer-product combination.

candidate_features <- prior_history[
  ,
  .(
    times_purchased = .N,
    last_order_number = max(order_number),
    mean_cart_position = mean(add_to_cart_order),
    product_reorder_rate = mean(reordered)
  ),
  by = .(user_id, product_id)
]

# Identify each customer's target order.

target_order_map <- orders[
  eval_set == "train",
  .(
    user_id,
    target_order_id = order_id,
    target_order_number = order_number
  )
]

# Products appearing in the target order receive label 1.

target_products <- unique(
  merge(
    train,
    target_order_map,
    by.x = "order_id",
    by.y = "target_order_id"
  )[
    ,
    .(user_id, product_id)
  ]
)

# Attach target order number to candidate products.

candidate_features <- merge(
  candidate_features,
  target_order_map[
    ,
    .(user_id, target_order_number)
  ],
  by = "user_id",
  all = FALSE
)

# Calculate the number of orders since the product was
# last purchased.

candidate_features[
  ,
  orders_since_last_purchase :=
    target_order_number - last_order_number
]

# Assign binary target labels.

candidate_features[, label := 0L]

candidate_features[
  target_products,
  on = .(user_id, product_id),
  label := 1L
]

cat("\nCANDIDATE FEATURE SUMMARY\n")
print(candidate_features[, .N, by = label])

cat(
  "Positive label percentage:",
  round(mean(candidate_features$label) * 100, 2),
  "%\n"
)

# Data quality checks.

cat("\nMISSING VALUES\n")
print(colSums(is.na(candidate_features)))

duplicate_count <- candidate_features[
  ,
  .N,
  by = .(user_id, product_id)
][N > 1, .N]

cat(
  "Duplicate customer-product rows:",
  duplicate_count,
  "\n"
)

stopifnot(
  duplicate_count == 0,
  all(candidate_features$label %in% c(0L, 1L)),
  all(is.finite(candidate_features$orders_since_last_purchase))
)


# 3. CUSTOMER-LEVEL TRAIN/VALIDATION/TEST SPLIT ------------

# Customers are split into three mutually exclusive groups.
# This prevents the same customer's records from appearing
# in both training and testing datasets.

set.seed(123)

all_users <- unique(candidate_features$user_id)
shuffled_users <- sample(all_users)

n_users <- length(shuffled_users)

train_end <- floor(0.70 * n_users)
validation_end <- floor(0.85 * n_users)

train_user_ids <- shuffled_users[
  seq_len(train_end)
]

validation_user_ids <- shuffled_users[
  seq.int(train_end + 1, validation_end)
]

test_user_ids <- shuffled_users[
  seq.int(validation_end + 1, n_users)
]

model_train <- candidate_features[
  user_id %in% train_user_ids
]

model_validation <- candidate_features[
  user_id %in% validation_user_ids
]

model_test <- candidate_features[
  user_id %in% test_user_ids
]

cat("\nDATA SPLIT SUMMARY\n")

cat(
  "Training customers:", length(train_user_ids),
  "| Records:", nrow(model_train), "\n"
)

cat(
  "Validation customers:", length(validation_user_ids),
  "| Records:", nrow(model_validation), "\n"
)

cat(
  "Test customers:", length(test_user_ids),
  "| Records:", nrow(model_test), "\n"
)

# Confirm that customer groups do not overlap.

stopifnot(
  length(intersect(train_user_ids, validation_user_ids)) == 0,
  length(intersect(train_user_ids, test_user_ids)) == 0,
  length(intersect(validation_user_ids, test_user_ids)) == 0
)


# 4. PREPARE MODEL FEATURES ---------------------------------

feature_columns <- c(
  "times_purchased",
  "orders_since_last_purchase",
  "mean_cart_position",
  "product_reorder_rate"
)

X_train <- as.matrix(
  model_train[, ..feature_columns]
)

X_validation <- as.matrix(
  model_validation[, ..feature_columns]
)

X_test <- as.matrix(
  model_test[, ..feature_columns]
)

y_train <- model_train$label
y_validation <- model_validation$label
y_test <- model_test$label

# Add an intercept column for logistic regression.

X_train_intercept <- cbind(
  intercept = 1,
  X_train
)

X_validation_intercept <- cbind(
  intercept = 1,
  X_validation
)

X_test_intercept <- cbind(
  intercept = 1,
  X_test
)

stopifnot(
  all(is.finite(X_train)),
  all(is.finite(X_validation)),
  all(is.finite(X_test))
)


# 5. EVALUATION FUNCTION ------------------------------------

# Calculate standard classification metrics.
# Explicit factor levels ensure that all confusion-matrix
# cells are present.

evaluate_model <- function(actual, predicted, probabilities) {
  
  confusion <- table(
    Actual = factor(actual, levels = c(0, 1)),
    Predicted = factor(predicted, levels = c(0, 1))
  )
  
  tn <- confusion["0", "0"]
  fp <- confusion["0", "1"]
  fn <- confusion["1", "0"]
  tp <- confusion["1", "1"]
  
  accuracy <- (tp + tn) / sum(confusion)
  
  precision <- if ((tp + fp) > 0) {
    tp / (tp + fp)
  } else {
    0
  }
  
  recall <- if ((tp + fn) > 0) {
    tp / (tp + fn)
  } else {
    0
  }
  
  f1 <- if ((precision + recall) > 0) {
    2 * precision * recall / (precision + recall)
  } else {
    0
  }
  
  roc_result <- pROC::roc(
    response = actual,
    predictor = probabilities,
    levels = c(0, 1),
    direction = "<",
    quiet = TRUE
  )
  
  metrics <- data.table(
    Accuracy = as.numeric(accuracy),
    Precision = as.numeric(precision),
    Recall = as.numeric(recall),
    F1_Score = as.numeric(f1),
    ROC_AUC = as.numeric(pROC::auc(roc_result))
  )
  
  list(
    confusion_matrix = confusion,
    metrics = metrics
  )
}


# 6. MODEL 1: LOGISTIC REGRESSION ---------------------------

cat("\nTRAINING LOGISTIC REGRESSION...\n")

logistic_model <- glm.fit(
  x = X_train_intercept,
  y = y_train,
  family = binomial(),
  control = glm.control(maxit = 50)
)

cat(
  "Convergence:", logistic_model$converged,
  "| Iterations:", logistic_model$iter,
  "\n"
)

cat("\nLOGISTIC REGRESSION COEFFICIENTS\n")
print(logistic_model$coefficients)

if (!logistic_model$converged) {
  warning("Logistic regression did not converge.")
}

# Validation predictions.

logistic_val_prob <- plogis(
  as.vector(
    X_validation_intercept %*%
      logistic_model$coefficients
  )
)

logistic_val_pred <- ifelse(
  logistic_val_prob >= 0.50,
  1L,
  0L
)

logistic_validation_results <- evaluate_model(
  y_validation,
  logistic_val_pred,
  logistic_val_prob
)

cat("\nLOGISTIC REGRESSION VALIDATION RESULTS\n")
print(logistic_validation_results$confusion_matrix)
print(logistic_validation_results$metrics)


# 7. MODEL 2: XGBOOST ---------------------------------------

cat("\nTRAINING XGBOOST...\n")

negative_count <- sum(y_train == 0)
positive_count <- sum(y_train == 1)

positive_weight <- negative_count / positive_count

cat(
  "Positive class weight:",
  round(positive_weight, 4),
  "\n"
)

dtrain <- xgb.DMatrix(
  data = X_train,
  label = y_train
)

dvalidation <- xgb.DMatrix(
  data = X_validation,
  label = y_validation
)

dtest <- xgb.DMatrix(
  data = X_test,
  label = y_test
)

xgb_params <- list(
  objective = "binary:logistic",
  eval_metric = "auc",
  max_depth = 6,
  eta = 0.1,
  subsample = 0.8,
  colsample_bytree = 0.8,
  scale_pos_weight = positive_weight
)

set.seed(123)

xgb_model <- xgb.train(
  params = xgb_params,
  data = dtrain,
  nrounds = 150,
  verbose = 0
)


# 8. XGBOOST VALIDATION AND THRESHOLD SELECTION ------------

cat("\nSELECTING XGBOOST CLASSIFICATION THRESHOLD...\n")

thresholds <- seq(0.10, 0.90, by = 0.05)

# Preallocate small result vectors
precision_values <- numeric(length(thresholds))
recall_values <- numeric(length(thresholds))
f1_values <- numeric(length(thresholds))

for (i in seq_along(thresholds)) {
  
  threshold <- thresholds[i]
  
  # Calculate confusion matrix counts without creating
  # a separate predictions vector
  predicted_positive <- xgb_val_prob >= threshold
  
  tp <- sum(predicted_positive & (y_validation == 1))
  fp <- sum(predicted_positive & (y_validation == 0))
  fn <- sum(!predicted_positive & (y_validation == 1))
  
  precision <- if ((tp + fp) > 0) tp / (tp + fp) else 0
  recall <- if ((tp + fn) > 0) tp / (tp + fn) else 0
  
  f1 <- if ((precision + recall) > 0) {
    2 * precision * recall / (precision + recall)
  } else {
    0
  }
  
  precision_values[i] <- precision
  recall_values[i] <- recall
  f1_values[i] <- f1
  
  rm(predicted_positive)
}

threshold_results <- data.frame(
  threshold = thresholds,
  precision = precision_values,
  recall = recall_values,
  f1_score = f1_values
)

threshold_results <- threshold_results[
  order(-threshold_results$f1_score),
]

print(threshold_results)

best_threshold <- threshold_results$threshold[1]

cat("\nBest threshold:", best_threshold, "\n")
cat("Best validation F1:", threshold_results$f1_score[1], "\n")

fwrite(
  threshold_results,
  "figures/xgboost_threshold_results.csv"
)


# 9. FINAL EVALUATION ON UNTOUCHED TEST DATA ---------------

# Logistic regression uses the default 0.50 threshold.
# XGBoost uses the threshold selected on validation data.

cat("\nFINAL TEST EVALUATION\n")

# Logistic regression.

logistic_test_prob <- plogis(
  as.vector(
    X_test_intercept %*%
      logistic_model$coefficients
  )
)

logistic_test_pred <- ifelse(
  logistic_test_prob >= 0.50,
  1L,
  0L
)

logistic_test_results <- evaluate_model(
  y_test,
  logistic_test_pred,
  logistic_test_prob
)

cat("\nLOGISTIC REGRESSION TEST RESULTS\n")
print(logistic_test_results$confusion_matrix)
print(logistic_test_results$metrics)


# XGBoost.

xgb_test_prob <- predict(
  xgb_model,
  dtest
)

xgb_test_pred <- ifelse(
  xgb_test_prob >= best_threshold,
  1L,
  0L
)

xgb_test_results <- evaluate_model(
  y_test,
  xgb_test_pred,
  xgb_test_prob
)

cat("\nXGBOOST TEST RESULTS\n")
print(xgb_test_results$confusion_matrix)
print(xgb_test_results$metrics)


# 10. COMPARE MODEL PERFORMANCE -----------------------------

model_comparison <- rbindlist(
  list(
    cbind(
      Model = "Logistic Regression",
      Threshold = 0.50,
      logistic_test_results$metrics
    ),
    cbind(
      Model = "XGBoost",
      Threshold = best_threshold,
      xgb_test_results$metrics
    )
  ),
  use.names = TRUE
)

cat("\nFINAL MODEL COMPARISON\n")
print(model_comparison)

fwrite(
  model_comparison,
  "figures/reorder_model_comparison.csv"
)


# 11. EXPORT CONFUSION MATRICES -----------------------------

logistic_cm_table <- as.data.table(
  as.table(logistic_test_results$confusion_matrix)
)

xgb_cm_table <- as.data.table(
  as.table(xgb_test_results$confusion_matrix)
)

fwrite(
  logistic_cm_table,
  "figures/logistic_regression_confusion_matrix.csv"
)

fwrite(
  xgb_cm_table,
  "figures/xgboost_confusion_matrix.csv"
)


# 12. SAVE EXPERIMENT SUMMARY -------------------------------

experiment_summary <- data.table(
  training_customers = length(train_user_ids),
  validation_customers = length(validation_user_ids),
  test_customers = length(test_user_ids),
  training_records = nrow(model_train),
  validation_records = nrow(model_validation),
  test_records = nrow(model_test),
  candidate_products = length(unique(candidate_features$product_id)),
  positive_examples = sum(candidate_features$label == 1),
  negative_examples = sum(candidate_features$label == 0),
  positive_percentage = mean(candidate_features$label == 1) * 100,
  xgboost_positive_weight = positive_weight,
  xgboost_selected_threshold = best_threshold
)

fwrite(
  experiment_summary,
  "figures/reorder_experiment_summary.csv"
)

cat("\nREORDER PREDICTION COMPLETED SUCCESSFULLY.\n")

# ============================================================
# END OF SCRIPT 7
# ============================================================