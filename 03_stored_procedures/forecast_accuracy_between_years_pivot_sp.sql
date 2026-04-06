-- ============================================================
-- Stored Procedure: forecast_accuracy_between_years_pivot
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Compare forecast accuracy between two fiscal years
--          per customer using a pivot pattern, returning only
--          customers whose accuracy declined
-- Parameters:
--   y1 (INT) — base year       e.g. 2020
--   y2 (INT) — comparison year e.g. 2021
-- Architecture: 2-layer CTE + conditional aggregation pivot
--   Layer 1 (accuracy_by_year) → Forecast accuracy per
--                                 customer for both years
--   Layer 2 (pivoted)          → Pivots rows into columns
--                                 using MAX(CASE WHEN) pattern
--                                 one column per fiscal year
--   Final SELECT               → Adds accuracy_change delta
--                                 filters declined customers
--                                 orders by worst decline first
-- Key technique: Pivot via MAX(CASE WHEN fiscal_year = y1)
--   MySQL has no native PIVOT — MAX(CASE WHEN) is the
--   standard pattern to transpose row values into columns
--   MAX() used as the aggregator since each customer has
--   exactly one row per year after GROUP BY in Layer 1
-- Difference from forecast_accuracy_between_years_LAG:
--   LAG version  → uses window function to compare years,
--                  outputs one row per customer in y2
--   Pivot version → uses conditional aggregation to place
--                   both years side by side in one row,
--                   adds explicit accuracy_change delta
--                   orders by largest decline first
--   Both identify declining customers — pivot version
--   is easier to read as a side-by-side comparison report
-- Output: Customers where accuracy_y2 < accuracy_y1,
--         with y1 accuracy, y2 accuracy, and delta shown
--         ordered by accuracy_change ASC (worst first)
-- Dependency: forecast_accuracy_base VIEW
--   (see 05_views/forecast_accuracy_base_view.sql)
-- ============================================================

DELIMITER $$

CREATE DEFINER=`root`@`localhost` PROCEDURE `forecast_accuracy_between_years_pivot`(
    IN y1 INT,
    IN y2 INT
)
BEGIN
    WITH 
    -- --------------------------------------------------------
    -- LAYER 1: Forecast accuracy per customer for both years
    -- --------------------------------------------------------
    accuracy_by_year AS (
        SELECT 
            customer_code,
            customer,
            market,
            fiscal_year,
            ROUND((1 - SUM(abs_error) / SUM(forecast_quantity)) * 100, 2) AS forecast_accuracy_pct
        FROM forecast_accuracy_base
        WHERE fiscal_year IN (y1, y2)
        GROUP BY customer_code, customer, market, fiscal_year
    ),

    -- --------------------------------------------------------
    -- LAYER 2: Pivot rows into columns using MAX(CASE WHEN)
    --          MySQL has no native PIVOT — this is the
    --          standard conditional aggregation equivalent
    --          MAX() works because each customer has exactly
    --          one row per year after Layer 1 GROUP BY
    -- --------------------------------------------------------
    pivoted AS (
        SELECT 
            customer_code,
            customer,
            market,
            MAX(CASE WHEN fiscal_year = y1 THEN forecast_accuracy_pct END) AS accuracy_y1,
            MAX(CASE WHEN fiscal_year = y2 THEN forecast_accuracy_pct END) AS accuracy_y2
        FROM accuracy_by_year
        GROUP BY customer_code, customer, market
    )

    -- --------------------------------------------------------
    -- OUTPUT: Customers where accuracy declined
    --         accuracy_change = y2 - y1 (negative = decline)
    --         ORDER BY ASC shows worst decline first
    -- --------------------------------------------------------
    SELECT 
        *,
        ROUND(accuracy_y2 - accuracy_y1, 2) AS accuracy_change
    FROM pivoted
    WHERE accuracy_y2 < accuracy_y1
    ORDER BY accuracy_change ASC;

END$$

DELIMITER ;
