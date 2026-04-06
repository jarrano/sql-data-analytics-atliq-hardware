# SQL Data Analytics — AtliQ Hardware
### Codebasics SQL Diploma | MySQL 8.0 | Beginner to Advanced

📜 [View Certificate](https://codebasics.io/certificate/CB-50-210737) — GUID: CB-50-210737 · Apr 2026  
👤 [LinkedIn](https://www.linkedin.com/in/jarrano)  
🌐 [Portfolio](https://codebasics.io/portfolio/Jorge-Arrao)

---

## Overview

SQL work completed as part of the **SQL Beginner to Advanced for Data Professionals** 
diploma at Codebasics (Certified April 2026, GUID: CB-50-210737).

**Database:** AtliQ Hardware gdb0041 — consumer electronics business operating across 
B2B, B2B2X, and B2C models  
**Records:** 1.5M+ across fiscal years 2018–2022  
**Tools:** MySQL 8.0 · MySQL Workbench  
**Fiscal year:** September start — all fiscal year lookups use JOIN on 
dim_date.calendar_date (3NF compliant)

---

## Repository Structure

| Folder | Contents |
|---|---|
| `01_gross_sales` | Gross sales exploration for Croma India — direct query and CTE approaches leading to stored procedure |
| `02_net_sales_pipeline` | Full 3-layer CTE net sales pipeline — gross price → pre-invoice deductions → post-invoice deductions |
| `03_stored_procedures` | 9 parameterized stored procedures for net sales, top customers, top products, market ranking, and forecast accuracy |
| `04_window_functions` | Reference file covering OVER, PARTITION BY, RANK, DENSE_RANK, ROW_NUMBER, LAG, and LEAD |
| `05_views` | forecast_accuracy_base VIEW — reusable foundation for all forecast accuracy SPs |
| `06_functions` | get_fiscal_year and get_fiscal_quarter scalar functions |

---

## Stored Procedures

| Procedure | Parameters | Output |
|---|---|---|
| `get_monthly_gross_sales_for_customer` | customer_codes (TEXT) | Monthly gross sales — supports multiple customers via FIND_IN_SET |
| `get_net_sales_by_fiscal_year` | fiscal_year (INT) | Top 5 markets by net sales in millions |
| `get_top_customers_by_net_sales` | market, fiscal_year, top_n | Top N customers by net sales for a given market |
| `get_top_n_markets_by_net_sales` | fiscal_year, top_n | Top N markets by net sales globally |
| `get_top_n_products_by_net_sales` | market, fiscal_year, top_n | Top N products by net sales for a given market |
| `get_top_n_products_per_division_by_qty_sold` | fiscal_year, top_n | Top N products per division ranked by quantity using DENSE_RANK |
| `get_forecast_accuracy_by_customer` | fiscal_year | Forecast accuracy metrics per customer |
| `get_forecast_accuracy_by_market` | fiscal_year | Forecast accuracy metrics per market |
| `forecast_accuracy_between_years_LAG` | y1, y2 | Customers with declining accuracy using LAG window function |
| `forecast_accuracy_between_years_pivot` | y1, y2 | Year-over-year accuracy comparison using MAX(CASE WHEN) pivot |
| `get_market_badge` | market, fiscal_year, OUT badge | Returns Gold/Silver badge based on quantity threshold |

---

## Key Technical Concepts

**3-Layer CTE Architecture**  
Net sales pipeline built as three sequential CTEs:  
`g_price` (gross price + pre-invoice rate) → `n_i_sales` (net invoice) → `n_sales` (final net sales)  
Separates business logic into maintainable, testable layers.

**Window Functions**  
`DENSE_RANK() OVER (PARTITION BY division)` — top N products per division with no rank gaps on ties  
`LAG() OVER (PARTITION BY customer_code)` — year-over-year forecast accuracy comparison  
`RANK()`, `ROW_NUMBER()`, `LEAD()` — covered in reference file with side-by-side comparison

**Pivot via Conditional Aggregation**  
`MAX(CASE WHEN fiscal_year = y1 THEN value END)` — MySQL has no native PIVOT; this is the standard pattern to transpose rows into columns

**Reusable VIEW as Base Layer**  
`forecast_accuracy_base` VIEW encapsulates the LEFT JOIN between forecast and actual sales, IFNULL handling, and net/abs error derivation — consumed by four stored procedures without duplicating logic

**OUT Parameter Pattern**  
`get_market_badge` uses DECLARE, IF/ELSE control flow, and an OUT parameter to return a scalar badge value to the caller rather than a result set

**Architectural Rule**  
All fiscal year lookups use `JOIN on dim_date.calendar_date` — the `fiscal_year` column on `fact_sales_monthly` is a denormalization (3NF violation) and is not used in any query in this repository

---

## Certificate
**SQL Beginner to Advanced for Data Professionals**  
Codebasics · April 2026 · GUID: CB-50-210737  
[Verify Certificate](https://codebasics.io/certificate/CB-50-210737)
