-- ============================================================
-- Stored Procedure: get_forecast_accuracy_by_customer
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Return forecast accuracy metrics per customer
--          for a given fiscal year
-- Parameter:
--   in_fiscal_year (INT) — target fiscal year e.g. 2021
-- Architecture: Single SELECT against forecast_accuracy_base
--   VIEW — all deduction logic encapsulated in the view,
--   keeping this SP clean and focused on aggregation only
-- Key metrics calculated:
--   total_sold_qty      → actual units sold
--   total_forecast_qty  → units forecasted
--   total_net_error     → signed error (forecast - actual)
--                         positive = over-forecast
--                         negative = under-forecast
--   total_abs_error     → absolute error (no sign)
--                         measures magnitude regardless of
--                         direction
--   forecast_accuracy_pct → (1 - abs_error/forecast_qty)*100
--                           100% = perfect forecast
--                           lower = greater deviation
-- Guard clause: WHERE in_fiscal_year <=
--   (SELECT MAX(date) FROM fact_sales_monthly)
--   Prevents query on future years with no actual sales data
-- Output: All customers ranked by forecast accuracy DESC
-- Dependency: forecast_accuracy_base VIEW
--   (see 05_views/forecast_accuracy_base_view.sql)
-- ============================================================

DELIMITER $$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_forecast_accuracy_by_customer`(
    in_fiscal_year INT
)
BEGIN
    SELECT 
        customer_code,
        customer,
        market,
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
    GROUP BY customer_code, customer, market
    ORDER BY forecast_accuracy_pct DESC;

END$$

DELIMITER ;
