-- ============================================================
-- View: forecast_accuracy_base
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Reusable base VIEW encapsulating the core logic
--          for forecast vs actual sales comparison
--          Used as the foundation for all forecast accuracy
--          stored procedures in this repository
-- Architecture: 2-layer CTE inside a VIEW definition
--   Layer 1 (fetch_data)  → Joins forecast, sales, customer,
--                           and date tables; filters to dates
--                           with actual sales data only
--   Layer 2 (calculate)   → Derives net_error and abs_error
--                           from forecast vs actual quantity
-- Key design decisions:
--   LEFT JOIN on fact_sales_monthly
--     → Some forecast dates may have no matching sales row
--       yet; LEFT JOIN retains forecast rows and returns
--       NULL for sold_quantity in those cases
--   IFNULL(sold_quantity, 0)
--     → Converts NULL from LEFT JOIN to 0 before arithmetic
--       prevents net_error and abs_error returning NULL
--   Date filter: date <= (SELECT MAX(date)
--                          FROM fact_sales_monthly)
--     → Excludes future forecast dates where no actual
--       sales exist yet; keeps results meaningful
-- Metrics derived:
--   net_error → forecast_quantity - IFNULL(sold_quantity, 0)
--               positive = over-forecast
--               negative = under-forecast
--   abs_error → ABS(net_error)
--               magnitude of error regardless of direction
--               used in forecast_accuracy_pct calculation:
--               (1 - SUM(abs_error)/SUM(forecast_qty))*100
-- Used by:
--   03_stored_procedures/get_forecast_accuracy_by_customer_sp.sql
--   03_stored_procedures/get_forecast_accuracy_by_market_sp.sql
--   03_stored_procedures/forecast_accuracy_between_years_LAG_sp.sql
--   03_stored_procedures/forecast_accuracy_between_years_pivot_sp.sql
-- Dependencies: fact_forecast_monthly, fact_sales_monthly,
--               dim_customer, dim_date
-- Note: fiscal_year sourced from dim_date.fiscal_year via
--       JOIN on calendar_date (3NF compliant)
-- ============================================================

CREATE OR REPLACE VIEW `forecast_accuracy_base` AS

WITH
-- --------------------------------------------------------
-- LAYER 1: Fetch and join forecast, sales, customer, date
--          LEFT JOIN on fact_sales_monthly retains all
--          forecast rows even when no matching sale exists
--          Date filter excludes future periods with no
--          actual sales data
-- --------------------------------------------------------
fetch_data AS (
    SELECT
        f.customer_code,
        f.date,
        dc.customer,
        dc.market,
        f.forecast_quantity,
        s.sold_quantity,
        dd.fiscal_year
    FROM fact_forecast_monthly f
    JOIN dim_date dd
        ON dd.calendar_date = f.date
    LEFT JOIN fact_sales_monthly s
        ON  f.customer_code = s.customer_code
        AND f.date          = s.date
        AND f.product_code  = s.product_code
    JOIN dim_customer dc
        ON dc.customer_code = f.customer_code
    WHERE f.date <= (
        SELECT MAX(date) FROM fact_sales_monthly
    )
),

-- --------------------------------------------------------
-- LAYER 2: Derive net_error and abs_error
--          IFNULL(sold_quantity, 0) handles NULLs from
--          the LEFT JOIN before arithmetic is applied
--          net_error: signed   — direction of deviation
--          abs_error: unsigned — magnitude of deviation
-- --------------------------------------------------------
calculate AS (
    SELECT
        customer_code,
        customer,
        market,
        fiscal_year,
        forecast_quantity,
        sold_quantity,
        date,
        forecast_quantity - IFNULL(sold_quantity, 0)       AS net_error,
        ABS(forecast_quantity - IFNULL(sold_quantity, 0))  AS abs_error
    FROM fetch_data
)

-- --------------------------------------------------------
-- OUTPUT: All columns exposed for SP consumption
-- --------------------------------------------------------
SELECT
    customer_code,
    customer,
    market,
    fiscal_year,
    forecast_quantity,
    sold_quantity,
    date,
    net_error,
    abs_error
FROM calculate;
