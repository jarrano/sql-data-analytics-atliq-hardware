-- ============================================================
-- Stored Procedure: get_market_badge
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Assign a Gold or Silver badge to a market based
--          on total quantity sold in a given fiscal year
-- Parameters:
--   in_market      (VARCHAR 45, IN)  — target market
--                                      defaults to "India"
--                                      if empty string passed
--   in_fiscal_year (YEAR, IN)        — target fiscal year
--   out_badge      (VARCHAR 45, OUT) — returns "Gold" or
--                                      "Silver" to the caller
-- Architecture: Procedural logic with OUT parameter
--   Notably different from other SPs in this repository —
--   uses DECLARE, IF/ELSE control flow, and an OUT parameter
--   rather than a CTE pipeline with a SELECT output
-- Key techniques:
--   OUT parameter   → returns a scalar value to the caller
--                     instead of a result set; caller must
--                     pass a session variable e.g. @badge
--   DECLARE         → local variable qty initialized to 0
--                     as a safe default before the SELECT
--   Default market  → IF in_market="" THEN sets "india"
--                     guards against empty string input
--   Badge threshold → qty > 5,000,000 = Gold, else Silver
-- Usage example:
--   CALL get_market_badge("India", 2021, @badge);
--   SELECT @badge;
-- Dependencies: fact_sales_monthly, dim_customer,
--               get_fiscal_year() function
-- Note: Uses get_fiscal_year() function for fiscal year
--       lookup rather than JOIN on dim_date — scalar
--       function applied directly on the date column
-- ============================================================

DELIMITER $$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_market_badge`(
    IN  in_market      VARCHAR(45),
    IN  in_fiscal_year YEAR,
    OUT out_badge      VARCHAR(45)
)
BEGIN
    DECLARE qty INT DEFAULT 0;

    -- --------------------------------------------------------
    -- Default market to India if empty string passed
    -- --------------------------------------------------------
    IF in_market = "" THEN
        SET in_market = "india";
    END IF;

    -- --------------------------------------------------------
    -- Retrieve total quantity sold for market + fiscal year
    -- SELECT ... INTO loads result into local variable qty
    -- --------------------------------------------------------
    SELECT 
        SUM(sold_quantity) INTO qty
    FROM fact_sales_monthly s
    JOIN dim_customer c
        ON s.customer_code = c.customer_code
    WHERE get_fiscal_year(s.date) = in_fiscal_year
        AND market = in_market
    GROUP BY c.market;

    -- --------------------------------------------------------
    -- Assign badge based on quantity threshold
    -- Gold: > 5,000,000 units | Silver: <= 5,000,000 units
    -- --------------------------------------------------------
    IF qty > 5000000 THEN
        SET out_badge = "Gold";
    ELSE
        SET out_badge = "Silver";
    END IF;

END$$

DELIMITER 
