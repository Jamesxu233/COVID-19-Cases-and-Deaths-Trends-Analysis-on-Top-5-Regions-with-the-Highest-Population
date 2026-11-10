# =============================================================================
# COVID-19 Cases and Deaths Trends Analysis on Top 5 Regions by Population
# Author: Ke Xu
# Course: Communication in Data Analysis
#
# Workflow:
#   1. Retrieve COVID-19 data at administrative level 2
#   2. Inspect and prepare analysis variables
#   3. Select the five most populated regions
#   4. Plot confirmed-case and death trends
#   5. Calculate policy/case correlations
#   6. Fit linear-regression baselines and forecast 30 days
#
# Notes:
# - Install packages separately (see README.md).
# - The source data are retrieved online and may change over time.
# - Correlation is descriptive; it does not imply causation.
# =============================================================================

# 0. Load packages ------------------------------------------------------------

required_packages <- c("COVID19", "dplyr", "tidyr", "ggplot2")

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Missing package(s): ", paste(missing_packages, collapse = ", "),
    ". Install them with install.packages()."
  )
}

library(COVID19)
library(dplyr)
library(tidyr)
library(ggplot2)

# Create output directory
output_dir <- "outputs"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# 1. Retrieve data ------------------------------------------------------------

# Level 2 represents state/administrative-area-level records in this project.
raw_df <- COVID19::covid19(level = 2)

required_columns <- c(
  "date", "confirmed", "deaths", "school_closing",
  "workplace_closing", "population", "administrative_area_level_2"
)

missing_columns <- setdiff(required_columns, names(raw_df))
if (length(missing_columns) > 0) {
  stop(
    "The retrieved dataset is missing required column(s): ",
    paste(missing_columns, collapse = ", "),
    ". Check the current COVID19 package data schema."
  )
}

# Inspect missingness before preprocessing.
missing_summary <- data.frame(
  variable = names(raw_df),
  missing_count = vapply(raw_df, function(x) sum(is.na(x)), integer(1)),
  row_count = nrow(raw_df)
)

print("Missing-value summary:")
print(missing_summary)

# 2. Prepare analysis fields --------------------------------------------------

analysis_df <- raw_df %>%
  transmute(
    date = as.Date(date),
    confirmed = as.numeric(confirmed),
    deaths = as.numeric(deaths),
    schoolcl = as.numeric(school_closing),
    workplacecl = as.numeric(workplace_closing),
    population = as.numeric(population),
    area_level1 = as.character(administrative_area_level_1),
    area_level2 = as.character(administrative_area_level_2)
  ) %>%
  filter(!is.na(date), !is.na(area_level2), area_level2 != "") %>%
  arrange(area_level2, date) %>%
  group_by(area_level2) %>%
  # LOCF is applied within each region, not across region boundaries.
  tidyr::fill(
    confirmed, deaths, schoolcl, workplacecl,
    .direction = "down"
  ) %>%
  ungroup()

# Fill remaining numeric missing values with the corresponding column mean.
numeric_analysis_vars <- c(
  "confirmed", "deaths", "schoolcl", "workplacecl", "population"
)

for (variable in numeric_analysis_vars) {
  x <- analysis_df[[variable]]
  if (anyNA(x)) {
    replacement <- mean(x, na.rm = TRUE)
    if (is.finite(replacement)) {
      x[is.na(x)] <- replacement
      analysis_df[[variable]] <- x
    }
  }
}

# Fill missing categorical labels.
analysis_df <- analysis_df %>%
  mutate(
    area_level1 = if_else(is.na(area_level1) | area_level1 == "",
                          "Unknown", area_level1),
    area_level2 = if_else(is.na(area_level2) | area_level2 == "",
                          "Unknown", area_level2)
  )

# The original report describes IQR-based outlier handling. For this revised
# workflow, we do not blanket-replace cumulative confirmed/death counts:
# large values and sudden increases may represent real epidemic events.
# If additional continuous, non-cumulative variables are added, evaluate
# outliers for those variables separately and document the chosen treatment.

# 3. Select the top five regions by population --------------------------------

region_population <- analysis_df %>%
  filter(!is.na(population)) %>%
  group_by(area_level2) %>%
  summarise(
    total_population = max(population, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(is.finite(total_population)) %>%
  arrange(desc(total_population))

top_regions <- region_population %>%
  slice_head(n = 5)

print("Top five regions by population:")
print(top_regions)

df_top <- analysis_df %>%
  semi_join(top_regions, by = "area_level2") %>%
  arrange(area_level2, date)

# Plot top-five population.
p_population <- ggplot(
  top_regions,
  aes(x = reorder(area_level2, total_population),
      y = total_population)
) +
  geom_col(fill = "skyblue") +
  geom_text(
    aes(label = scales::comma(total_population)),
    hjust = -0.1,
    size = 3.5
  ) +
  coord_flip() +
  labs(
    title = "Top 5 Regions by Population",
    x = "Region",
    y = "Population"
  ) +
  theme_minimal()

ggsave(
  file.path(output_dir, "top_5_regions_by_population.png"),
  p_population, width = 8, height = 5, dpi = 300
)

# 4. Trend analysis -----------------------------------------------------------

p_cases <- ggplot(
  df_top,
  aes(x = date, y = confirmed)
) +
  geom_line(color = "blue", linewidth = 0.7, na.rm = TRUE) +
  facet_wrap(~ area_level2, scales = "free_y") +
  labs(
    title = "COVID-19 Confirmed Cases Trends Over Time",
    x = "Date",
    y = "Cumulative Confirmed Cases"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    text = element_text(size = 11)
  )

ggsave(
  file.path(output_dir, "confirmed_cases_trends.png"),
  p_cases, width = 10, height = 7, dpi = 300
)

p_deaths <- ggplot(
  df_top,
  aes(x = date, y = deaths)
) +
  geom_line(color = "black", linewidth = 0.7, na.rm = TRUE) +
  facet_wrap(~ area_level2, scales = "free_y") +
  labs(
    title = "COVID-19 Deaths Trends Over Time",
    x = "Date",
    y = "Cumulative Deaths"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    text = element_text(size = 11)
  )

ggsave(
  file.path(output_dir, "deaths_trends.png"),
  p_deaths, width = 10, height = 7, dpi = 300
)

# 5. Policy/case correlation analysis ----------------------------------------

correlation_data <- df_top %>%
  group_by(area_level2) %>%
  summarise(
    corr_school_closing = cor(
      confirmed, schoolcl,
      use = "complete.obs",
      method = "pearson"
    ),
    corr_workplace_closing = cor(
      confirmed, workplacecl,
      use = "complete.obs",
      method = "pearson"
    ),
    .groups = "drop"
  )

print("Policy/case correlation coefficients:")
print(correlation_data)

correlation_long <- correlation_data %>%
  pivot_longer(
    cols = starts_with("corr_"),
    names_to = "policy",
    values_to = "correlation"
  ) %>%
  mutate(
    policy = recode(
      policy,
      corr_school_closing = "School Closures",
      corr_workplace_closing = "Workplace Closures"
    )
  )

p_correlation <- ggplot(
  correlation_long,
  aes(x = area_level2, y = correlation, fill = policy)
) +
  geom_col(position = "dodge") +
  geom_hline(yintercept = 0, linewidth = 0.3) +
  labs(
    title = "Correlation Between Confirmed Cases and Policy Closures",
    x = "Region",
    y = "Pearson Correlation Coefficient",
    fill = "Policy Type"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

ggsave(
  file.path(output_dir, "policy_case_correlations.png"),
  p_correlation, width = 9, height = 5.5, dpi = 300
)

# 6. Regression models and 30-day forecasts -----------------------------------
#
# The original report describes two regression models. To make the modeling
# population explicit and consistent with the regional analysis, this revised
# script first aggregates the five selected regions by date using their daily
# mean values, then fits one model for each outcome.

daily_top5 <- df_top %>%
  group_by(date) %>%
  summarise(
    confirmed = mean(confirmed, na.rm = TRUE),
    deaths = mean(deaths, na.rm = TRUE),
    schoolcl = mean(schoolcl, na.rm = TRUE),
    workplacecl = mean(workplacecl, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(date) %>%
  mutate(time = as.numeric(date - min(date)))

model_data <- daily_top5 %>%
  filter(
    is.finite(confirmed),
    is.finite(deaths),
    is.finite(schoolcl),
    is.finite(workplacecl),
    is.finite(time)
  )

if (nrow(model_data) < 10) {
  stop("Not enough complete daily observations to fit the regression models.")
}

# Linear regression for average confirmed cases and deaths across top-five regions.
model_confirmed <- lm(
  confirmed ~ time + schoolcl + workplacecl,
  data = model_data
)

model_deaths <- lm(
  deaths ~ time + schoolcl + workplacecl,
  data = model_data
)

cat("\nConfirmed-cases model summary:\n")
print(summary(model_confirmed))

cat("\nDeaths model summary:\n")
print(summary(model_deaths))

# 7. Forecast the next 30 days -----------------------------------------------

last_date <- max(model_data$date, na.rm = TRUE)

future_dates <- data.frame(
  date = seq.Date(from = last_date + 1, by = "day", length.out = 30),
  time = max(model_data$time, na.rm = TRUE) + seq_len(30),
  # Scenario assumption: future policy indicators remain at their historical
  # mean across the selected regions.
  schoolcl = mean(model_data$schoolcl, na.rm = TRUE),
  workplacecl = mean(model_data$workplacecl, na.rm = TRUE)
)

pred_confirmed <- predict(
  model_confirmed,
  newdata = future_dates,
  interval = "confidence",
  level = 0.95
)

pred_deaths <- predict(
  model_deaths,
  newdata = future_dates,
  interval = "confidence",
  level = 0.95
)

future_confirmed <- bind_cols(
  future_dates,
  as.data.frame(pred_confirmed)
)

future_deaths <- bind_cols(
  future_dates,
  as.data.frame(pred_deaths)
)

p_forecast_confirmed <- ggplot(
  future_confirmed,
  aes(x = date, y = fit)
) +
  geom_ribbon(
    aes(ymin = lwr, ymax = upr),
    fill = "blue", alpha = 0.2
  ) +
  geom_line(color = "blue", linewidth = 0.8) +
  labs(
    title = "30-Day Forecast of Average Confirmed Cases",
    subtitle = "95% confidence interval for the mean response",
    x = "Date",
    y = "Average Cumulative Confirmed Cases"
  ) +
  theme_minimal()

ggsave(
  file.path(output_dir, "confirmed_cases_forecast.png"),
  p_forecast_confirmed, width = 9, height = 5.5, dpi = 300
)

p_forecast_deaths <- ggplot(
  future_deaths,
  aes(x = date, y = fit)
) +
  geom_ribbon(
    aes(ymin = lwr, ymax = upr),
    fill = "grey40", alpha = 0.25
  ) +
  geom_line(color = "black", linewidth = 0.8) +
  labs(
    title = "30-Day Forecast of Average Deaths",
    subtitle = "95% confidence interval for the mean response",
    x = "Date",
    y = "Average Cumulative Deaths"
  ) +
  theme_minimal()

ggsave(
  file.path(output_dir, "deaths_forecast.png"),
  p_forecast_deaths, width = 9, height = 5.5, dpi = 300
)

# 8. Model evaluation ---------------------------------------------------------

model_metrics <- data.frame(
  outcome = c("confirmed", "deaths"),
  r_squared = c(
    summary(model_confirmed)$r.squared,
    summary(model_deaths)$r.squared
  ),
  rmse_in_sample = c(
    sqrt(mean(residuals(model_confirmed)^2, na.rm = TRUE)),
    sqrt(mean(residuals(model_deaths)^2, na.rm = TRUE))
  )
)

cat("\nIn-sample model metrics:\n")
print(model_metrics)

write.csv(
  top_regions,
  file.path(output_dir, "top_5_regions.csv"),
  row.names = FALSE
)

write.csv(
  correlation_data,
  file.path(output_dir, "policy_case_correlations.csv"),
  row.names = FALSE
)

write.csv(
  model_metrics,
  file.path(output_dir, "regression_model_metrics.csv"),
  row.names = FALSE
)

cat("\nAnalysis completed. Figures and summary tables were saved to: ",
    normalizePath(output_dir), "\n")
