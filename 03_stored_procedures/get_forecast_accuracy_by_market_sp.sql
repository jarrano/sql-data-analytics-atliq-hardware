-- ============================================================
-- Stored Procedure: get_forecast_accuracy_by_market
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Return forecast accuracy metrics aggregated
--          by market for a given fiscal year
-- Parameter:
--   in_fiscal_year (INT) — target fiscal year e.g. 2021
-- Architecture: Single SELECT against forecast_accuracy_base
--   VIEW — same pattern as get_forecast_accuracy_by_customer
--   but aggregated at market level instead of customer level
-- Key metrics calculated:
--   customer_count      → COUNT(DISTINCT customer_code)
--                         number of customers per market
--                         not present in the customer-level SP
--   total_sold_qty      → actual units sold
--   total_forecast_qty  → units forecasted
--   total_net_error     → signed error (forecast - actual)
--                         positive = over-forecast
--                         negative = under-forecast
--   total_abs_error     → absolute error (no sign)
--   forecast_accuracy_pct → (1 - abs_error/forecast_qty)*100
--                           100% = perfect forecast
-- Guard clause: WHERE in_fiscal_year <=
--   (SELECT MAX(date) FROM fact_sales_monthly)
--   Prevents query on future years with no actual sales data
-- Difference from get_forecast_accuracy_by_customer:
--   Groups by market instead of customer
--   Adds customer_count — shows market breadth
--   Useful for identifying which markets have systemic
--   over or under-forecasting patterns
-- Output: All markets ranked by forecast accuracy DESC
-- Dependency: forecast_accuracy_base VIEW
--   (see 05_views/forecast_accuracy_base_view.sql)
-- ============================================================

DELIMITER $$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_forecast_accuracy_by_market`(
    in_fiscal_year INT
)
BEGIN
    SELECT 
        market,
        COUNT(DISTINCT customer_code)                                   AS customer_count,
        SUM(sold_quantity)                                              AS total_sold_qty,
        SUM(forecast_quantity)                                          AS total_forecast_qty,
        SUM(net_error)                                                  AS total_net_error,
        SUM(abs_error)                                                  AS total_abs_error,
        ROUND((1 - SUM(abs_error) / SUM(forecast_quantity)) * 100, 2)  AS forecast_accuracy_pct
    FROM forecast_accuracy_base
    WHERE fiscal_year = in_fiscal_year
        AND in_fiscal_year <= (
            SELECT MAX(date) FROM fact_sales_monthly
        )
    GROUP BY market
    ORDER BY forecast_accuracy_pct DESC;

END$$

DELIMITER ;
