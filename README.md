# Market Basket Analysis and Customer Behaviour in Large-Scale Retail Transaction Data

## 1. Project Overview

This project investigates purchasing patterns and customer behaviour using the **Instacart Market Basket Analysis** dataset.

The study applies data analysis, association rule mining, customer segmentation, and machine learning to understand how customers purchase products, identify relationships between frequently purchased items, group customers according to their shopping behaviour, and predict repeat purchases.

The project was completed as part of the MSc Data Science programme.

## 2. Research Objectives

The main objectives are to:

1. Explore customer ordering patterns, including order frequency, basket sizes, days of the week, and hours of the day.
2. Identify frequently purchased products and the distribution of purchases across product departments.
3. Discover product associations using Market Basket Analysis and the Apriori algorithm.
4. Segment customers according to purchasing frequency, basket size, reorder behaviour, and ordering intervals.
5. Develop and evaluate machine learning models for predicting repeat purchases.
6. Interpret the findings and discuss their implications for retail decision-making.

## 3. Dataset

The project uses the **Instacart Market Basket Analysis** dataset, originally released through a Kaggle competition.

Dataset source:

https://www.kaggle.com/competitions/instacart-market-basket-analysis/data

The dataset contains six principal CSV files:

| File | Description |
|---|---|
| `orders.csv` | Customer order information, including order sequence, day, hour, and time since previous order. |
| `order_products__prior.csv` | Products purchased in customers' prior orders. |
| `order_products__train.csv` | Products in the target training orders, including reorder labels. |
| `products.csv` | Product information and aisle and department identifiers. |
| `aisles.csv` | Aisle information. |
| `departments.csv` | Department information. |

**Dataset note:** The original Kaggle data is not included in this repository. Users must download it themselves and comply with the competition's terms.

### Download and setup

1. Visit the Kaggle dataset link above.
2. Sign in to your Kaggle account.
3. Accept the competition rules if prompted.
4. Download the dataset files.
5. Extract the downloaded archive.
6. Place the six CSV files inside the project's `data/` directory.

The expected structure is:

```text
market-basket-analysis-instacart/
├── data/
│   ├── orders.csv
│   ├── order_products__prior.csv
│   ├── order_products__train.csv
│   ├── products.csv
│   ├── aisles.csv
│   └── departments.csv
```

## 4. Methodology and Analysis

The project is organised into seven sequential R scripts.

### 4.1 Data Loading and Setup

**Script:** `R/1_setup.R`

Loads the required R packages and six dataset files. It also checks the availability of the expected files and columns and reports the dimensions of the loaded datasets.

### 4.2 Exploratory Data Analysis and Data Profiling

**Script:** `R/2_data_profiling.R`

Examines the structure and quality of the dataset through:

- Dataset dimensions and variable types.
- Sample observations.
- Missing-value analysis.
- Duplicate checks.
- Unique customer, order, and product counts.
- Reorder distribution.

Missing values in `days_since_prior_order` are expected for customers' first recorded orders.

### 4.3 Ordering Patterns

**Script:** `R/3_ordering_patterns.R`

Investigates when customers place orders and how many products they purchase per order.

The analysis includes:

- Ordering activity by day of the week and hour of the day.
- Basket-size distribution.
- Descriptive statistics for basket sizes.

Key finding: The prior-order data contains 3,214,874 orders, with a mean basket size of approximately 10.09 products and a median of 8.

### 4.4 Product Analysis

**Script:** `R/4_product_analysis.R`

Examines product popularity and purchasing frequency across departments.

The analysis includes:

- Most frequently purchased products.
- Purchase distribution across departments.
- Product and department summaries.

The most frequently purchased product was **Banana**, with 472,565 recorded purchases, followed by Bag of Organic Bananas, with 379,450.

Produce was the leading department by purchase frequency.

### 4.5 Market Basket Analysis and Association Rule Mining

**Script:** `R/5_association_rules.R`

Uses the Apriori algorithm to identify product associations.

The analysis uses a reproducible sample of 50,000 prior orders and the following parameters:

- Minimum support: 0.005
- Minimum confidence: 0.20
- Minimum rule length: 2
- Maximum rule length: 3

A total of 45 association rules were identified.

The strongest rule by lift was:

**Organic Cilantro → Limes**

| Metric | Value |
|---|---:|
| Support | 0.00548 |
| Confidence | 0.253469 |
| Lift | 5.930487 |
| Count | 274 |

The lift indicates that the two products occur together substantially more often than would be expected if their purchases were independent.

Association rules identify purchasing relationships; they do not establish causation.

### 4.6 Customer Segmentation

**Script:** `R/6_customer_segmentation.R`

Applies K-means clustering to group customers according to four behavioural features:

- Total number of orders.
- Average basket size.
- Reorder rate.
- Average order interval.

The analysis uses four clusters.

| Segment | Customers | Percentage | Average Orders | Average Basket Size | Reorder Rate | Average Order Interval |
|---|---:|---:|---:|---:|---:|---:|
| Low-frequency, low-repeat | 71,999 | 34.92% | 6.82 | 7.74 | 25.12% | 21.66 days |
| Regular, moderate-repeat | 73,921 | 35.85% | 15.70 | 7.65 | 49.43% | 11.99 days |
| Large-basket shoppers | 34,413 | 16.69% | 12.01 | 19.25 | 46.38% | 16.36 days |
| Frequent, highly loyal | 25,876 | 12.55% | 52.41 | 10.30 | 71.69% | 6.84 days |

The cluster labels are interpretations of the observed customer behaviour rather than labels supplied by the original dataset.

### 4.7 Repeat Purchase Prediction

**Script:** `R/7_reorder_prediction.R`

Develops and compares two classification models:

1. Logistic Regression.
2. XGBoost.

The task is to predict whether a customer will repurchase a product they have previously purchased.

The candidate customer-product dataset contains 8,474,661 records, with a positive purchase rate of approximately 9.78%.

Four predictive features were used:

- `times_purchased`
- `orders_since_last_purchase`
- `mean_cart_position`
- `product_reorder_rate`

Customers were separated into training, validation, and test groups to prevent customer overlap between the splits.

The XGBoost classification threshold was selected using validation-set F1-score optimisation.

#### Model comparison

| Metric | Logistic Regression | XGBoost |
|---|---:|---:|
| Accuracy | 0.9025 | 0.8576 |
| Precision | 0.6091 | 0.3493 |
| Recall | 0.0341 | 0.5125 |
| F1-score | 0.0646 | 0.4154 |
| ROC-AUC | 0.8085 | 0.8140 |
| Classification threshold | 0.50 | 0.70 |

XGBoost achieved substantially better recall and F1-score, indicating a stronger ability to identify products that customers would repurchase. However, it produced more false positives and had lower precision.

Logistic Regression achieved higher accuracy and precision but missed most actual repeat purchases. Accuracy alone is therefore not sufficient for evaluating this imbalanced classification problem.

**Important limitation:** The prediction task covers previously purchased customer-product combinations only. It is not a complete next-basket recommendation system. The candidate-generation approach covered approximately 59.86% of the actual target product lines, leaving approximately 40.14% outside the candidate universe.

## 5. Technology Stack

- **R:** Data analysis and statistical computing.
- **data.table:** Efficient processing of large transaction datasets.
- **ggplot2:** Data visualisation.
- **arules:** Association rule mining.
- **arulesViz:** Visualisation of association rules, where used.
- **cluster and stats:** Clustering and statistical analysis.
- **xgboost:** Gradient-boosted classification.
- **pROC:** ROC-AUC evaluation.

## 6. Repository Structure

```text
market-basket-analysis-instacart/
│
├── R/
│   ├── 1_setup.R
│   ├── 2_data_profiling.R
│   ├── 3_ordering_patterns.R
│   ├── 4_product_analysis.R
│   ├── 5_association_rules.R
│   ├── 6_customer_segmentation.R
│   └── 7_reorder_prediction.R
│
├── data/
│   └── README.md
│
├── figures/
│   └── Generated charts and visualisations
│
├── results/
│   └── Generated CSV summaries and model results
│
├── report/
│   └── Final report files
│
├── .gitignore
└── README.md
```

## 7. Running the Project

### Requirements

- R (a recent version is recommended).
- RStudio (recommended).
- The six Instacart CSV files downloaded from Kaggle.
- Required R packages.

Install the packages in the R console:

```r
install.packages(c(
  "data.table",
  "ggplot2",
  "arules",
  "arulesViz",
  "xgboost",
  "pROC",
  "dplyr",
  "tidyr"
))
```

### Execution order

Run the scripts in the following order:

```text
1_setup.R
2_data_profiling.R
3_ordering_patterns.R
4_product_analysis.R
5_association_rules.R
6_customer_segmentation.R
7_reorder_prediction.R
```

Set the working directory to the repository's root folder before executing the scripts. The scripts are designed to use the `data/`, `figures/`, and `results/` directories relative to that location.

For reproducibility, execute the scripts sequentially from a fresh R session.

## 8. Reproducibility and Limitations

The project uses a fixed random seed for the sampled association-rule analysis. The customer segmentation and prediction experiments also use defined modelling procedures.

Important limitations include:

- The association-rule analysis uses a sample of 50,000 prior orders rather than the complete transaction history.
- K-means clustering requires the selection of a cluster count; four clusters were used for the reported segmentation.
- Repeat-purchase prediction excludes products a customer has never purchased before.
- The prediction dataset is imbalanced, making precision, recall, F1-score, and ROC-AUC important evaluation measures.
- Findings describe patterns in the Instacart dataset and should not automatically be generalised to all retail customers.

## 9. Project Outputs

The `figures/` directory contains generated visualisations, including:

- Ordering activity heatmap.
- Basket-size distribution.
- Department purchase analysis.
- Association-rule network.
- Customer segmentation elbow plot.
- Customer cluster visualisation.

The analysis also exports CSV files containing product summaries, ordering statistics, association rules, customer cluster profiles, cluster assignments, and model evaluation results.

## 10. Conclusion

This project combines exploratory data analysis, market basket analysis, customer segmentation, and machine learning to examine retail transaction behaviour.

The findings demonstrate how transaction data can support product association discovery, customer profiling, and repeat-purchase prediction. The comparison of Logistic Regression and XGBoost also highlights the importance of selecting evaluation metrics that reflect the objectives of an imbalanced classification problem.

The project provides a practical analytical workflow for extracting insights from large-scale retail transaction data.