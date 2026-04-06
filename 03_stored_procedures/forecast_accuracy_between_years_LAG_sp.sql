-- ============================================================
-- Stored Procedure: forecast_accuracy_between_years_LAG
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Identify customers whose forecast accuracy
--          declined between two fiscal years
-- Parameters:
--   y1 (INT) — base year    e.g. 2020
--   y2 (INT) — comparison year e.g. 2021
-- Architecture: 2-layer CTE + LAG window function
--   Layer 1 (accuracy_by_year) → Forecast accuracy metrics
--                                 per customer for BOTH years
--                                 in a single pass using
--                                 IN (y1, y2) filter
--   Layer 2 (accuracy_with_lag) → LAG() retrieves each
--                                  customer's y1 accuracy
--                                  as prev_year_accuracy
--                                  alongside their y2 row
--   Filter → WHERE forecast_accuracy_pct < prev_year_accuracy
--             AND fiscal_year = y2
--             Returns only y2 rows where accuracy dropped
-- Key technique: LAG() with PARTITION BY customer_code
--   PARTITION BY customer_code — each customer gets its own
--   independent LAG calculation
--   ORDER BY fiscal_year — ensures y1 is the lagged value
--   and y2 is the current row
-- Business insight: flags customers with deteriorating
--   forecast accuracy for supply chain review
-- Output: Customers in y2 where accuracy < y1 accuracy,
--         with both current and previous year values shown
-- Dependency: forecast_accuracy_base VIEW
--   (see 05_views/forecast_accuracy_base_view.sql)
-- ============================================================

DELIMITER $$

CREATE DEFINER=`root`@`localhost` PROCEDURE `forecast_accuracy_between_years_LAG`(
    IN y1 INT,
    IN y2 INT
)
BEGIN
    WITH 
    -- --------------------------------------------------------
    -- LAYER 1: Forecast accuracy per customer for both years
    --          IN (y1, y2) fetches both years in a single pass
    -- --------------------------------------------------------
    accuracy_by_year AS (
        SELECT 
            customer_code,
            customer,
            market,
            fiscal_year,
            SUM(sold_quantity)                                              AS total_sold_qty,
            SUM(forecast_quantity)                                          AS total_forecast_qty,
            SUM(net_error)                                                  AS total_net_error,
            SUM(abs_error)                                                  AS total_abs_error,
            ROUND((1 - SUM(abs_error) / SUM(forecast_quantity)) * 100, 2)  AS forecast_accuracy_pct
        FROM forecast_accuracy_base
        WHERE fiscal_year IN (y1, y2)
        GROUP BY customer_code, customer, market, fiscal_year
    ),

    -- --------------------------------------------------------
    -- LAYER 2: LAG() retrieves previous year accuracy
    --          PARTITION BY customer_code — independent per
    --          customer; ORDER BY fiscal_year ensures y1
    --          becomes the lagged value on the y2 row
    -- --------------------------------------------------------
    accuracy_with_lag AS (
        SELECT 
            *,
            LAG(forecast_accuracy_pct) OVER (
                PARTITION BY customer_code 
                ORDER BY fiscal_year
            ) AS prev_year_accuracy
        FROM accuracy_by_year
    )

    -- --------------------------------------------------------
    -- OUTPUT: Customers in y2 where accuracy declined vs y1
    -- --------------------------------------------------------
    SELECT *
    FROM accuracy_with_lag
    WHERE forecast_accuracy_pct < prev_year_accuracy 
        AND fiscal_year = y2;

END$$

DELIMITER ;
