# COVID-19 Cases and Deaths Trends Analysis on Top 5 Regions by Population

An R-based data analysis project exploring COVID-19 case and death trends across five highly populated administrative regions, examining the association between school/workplace closure policies and reported cases, and building simple 30-day linear-regression forecasts with confidence intervals.

**Author:** Ke Xu  
**Course:** Communication in Data Analysis  
**Institution:** University of Maryland, College Park  
**Language:** R

## Project overview

The project uses the `COVID19` R package to retrieve COVID-19 data at administrative level 2, then:

1. Inspects missingness and prepares the epidemiological and policy variables.
2. Selects the five regions with the largest recorded population.
3. Visualizes confirmed-case and death trends from 2020 onward.
4. Calculates region-level correlations between confirmed cases and school/workplace closure indicators.
5. Fits linear-regression baselines for the average daily confirmed cases and deaths across the selected regions.
6. Forecasts the next 30 days and visualizes confidence intervals for the fitted mean response.

The analysis is intended for exploratory and educational purposes. It is not a causal evaluation of public-health policies and should not be used as epidemiological guidance.

## Research questions

- How did reported cumulative COVID-19 cases and deaths evolve in the five selected regions?
- How were school-closure and workplace-closure policy indicators associated with reported confirmed cases in each region?
- What do simple time-and-policy linear regression models suggest about the next 30 days, and how does forecast uncertainty change over time?

## Data source and variables

The R script retrieves data with:

```r
COVID19::covid19(level = 2)
```

The project uses these fields from the returned data:

| Variable | Description |
|---|---|
| `date` | Observation date |
| `confirmed` | Cumulative confirmed COVID-19 cases |
| `deaths` | Cumulative reported deaths |
| `school_closing` | School-closure policy indicator |
| `workplace_closing` | Workplace-closure policy indicator |
| `population` | Population associated with the administrative region |
| `administrative_area_level_1` | Higher-level administrative area |
| `administrative_area_level_2` | Region used for the analysis |

The original report describes the source data as combining epidemiological, demographic, and policy information, including information from WHO, government sources, and policy-tracking initiatives. The script obtains the data through the `COVID19` package rather than manually downloading separate files.

**Data availability note:** The package retrieves data from an external source. The returned records and historical coverage can change over time. Consequently, rerunning the script later may not reproduce every figure or statistic in the original course report exactly.

## Repository structure

A suggested repository layout is:

```text
.
├── README.md
├── code/
│   └── covid19_analysis.R
├── reports/
│   ├── final project.pdf 
│   └── final project proposal.pdf
├── presentation/
│   └── final project presentation.pptx
└── outputs/
    ├── top 5 regions by population.png
    ├── confirmed cases trends.png
    ├── deaths trends.png
    ├── cases and policy correlation .png
    ├── predicted confirmed cases.png
    └── predicted deaths.png
```

Only include the report, presentation, and output files in the repository if you choose to upload them. The analysis script creates the `outputs/` directory and saves the generated plots there.

## Requirements

- R (recommended: a recent R 4.x release)
- Internet access when retrieving the source data
- The following R packages:
  - `COVID19`
  - `dplyr`
  - `tidyr`
  - `ggplot2`
  - `readr` (optional, if you later export tables)

Install the required packages in the R console:

```r
install.packages(c("COVID19", "dplyr", "tidyr", "ggplot2"))
```

## How to run

1. Clone or download this repository.
2. Open the project in RStudio, or set the working directory to the repository root.
3. Install the required packages.
4. Run the analysis script:

```r
source("code/covid19_analysis.R")
```

If the script is stored in the repository root instead, run:

```r
source("covid19_analysis.R")
```

The script retrieves the data, performs the analysis, prints model summaries and evaluation metrics, and saves the figures under `outputs/`.

## Methodology

### 1. Missing-data inspection and preparation

The script reports missing-value counts for the source data. It sorts observations by region and date before applying last-observation-carried-forward (LOCF) imputation to cumulative confirmed cases, deaths, and the two policy indicators. Remaining missing values in the analysis fields are handled with numeric means where applicable; missing region labels are marked as `Unknown`.

LOCF assumes that the most recent observed value remains applicable until another observation is recorded. This assumption should be reviewed when using the data for formal analysis.

### 2. Top-five region selection

The script converts population values to numeric, identifies the five regions with the largest recorded population, and filters the data to those regions. The selected regions are printed during execution.

### 3. Trend analysis

Faceted line charts show cumulative confirmed cases and cumulative deaths over time, with a separate panel for each selected region.

### 4. Policy association analysis

For each selected region, the script calculates Pearson correlations between confirmed cases and:
- the school-closure indicator;
- the workplace-closure indicator.

The coefficients are displayed in a grouped bar chart.

**Interpretation caution:** Correlation does not establish causation. Policy measures may have been introduced in response to rising case counts; timing, testing, reporting practices, mobility, vaccination, and other confounders are not controlled for in this analysis.

### 5. Regression and 30-day forecast

For a transparent pooled baseline, the revised script aggregates the selected regions by date and calculates the daily mean of confirmed cases, deaths, and policy indicators. It then fits two separate ordinary least squares models:

- `confirmed ~ time + school_closure + workplace_closure`
- `deaths ~ time + school_closure + workplace_closure`

The next 30 days are forecast using the mean observed policy-indicator values as the future policy scenario. The script reports R-squared and in-sample RMSE and plots the fitted forecasts with 95% confidence intervals for the **mean response**.

A confidence interval for the mean response is not the same as a prediction interval for an individual future observation. The linear models are simple baselines and do not explicitly model autocorrelation, structural breaks, or nonlinear epidemic dynamics.

## Results reported in the original course report

The submitted report records the following model-fit results:

| Outcome | Reported R-squared |
|---|---:|
| Confirmed cases | 0.85 |
| Deaths | 0.78 |

These values are taken from the original report, not guaranteed outputs of the revised script. The data source may change, and the revised script uses an explicit daily aggregation of the selected five regions. Re-run the script and use its printed metrics if you need results corresponding exactly to the current code and data snapshot.

The original analysis identified different correlation patterns across regions. In particular, the report described negative correlations for both policy indicators in Antioquia and a negative correlation between workplace closures and confirmed cases in Western Cape. These are descriptive associations, not estimates of causal policy effects.

## Key limitations and reproducibility notes

- The `COVID19` package retrieves external data; pinning a dated data snapshot would improve reproducibility.
- The five-region selection depends on the population values returned by the source.
- LOCF is a simple imputation strategy and may not be appropriate for every variable or every missingness pattern.
- Cumulative case and death counts can contain meaningful spikes. Automatically replacing extreme cumulative values with IQR-based medians can erase real epidemic changes; the revised script therefore does not apply blanket IQR replacement to these outcomes.
- Policy/case correlations are descriptive and do not establish that a policy caused a change in case counts.
- Linear regression is a baseline forecasting method. Its confidence intervals do not account for all sources of time-series uncertainty.

## References

- COVID19 R package: <https://cran.r-project.org/package=COVID19>
- Original course report and presentation: see the `reports/` and `presentation/` folders if included in this repository.

## License

Add a license file if you intend to permit reuse. Do not assume that the source dataset, package data, report, and code all share the same license.
