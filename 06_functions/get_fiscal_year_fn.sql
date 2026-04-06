-- ============================================================
-- Function: get_fiscal_year
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Convert a calendar date to its corresponding
--          AtliQ Hardware fiscal year
-- Parameter:
--   calendar_date (DATE) — any calendar date
-- Returns: INT — fiscal year the date belongs to
-- Fiscal year definition:
--   AtliQ Hardware fiscal year starts in September
--   e.g. Sep 2020 – Aug 2021 = fiscal year 2021
-- Logic: ADD 4 months to the calendar date, then extract
--   the year — shifting September forward to January makes
--   YEAR() return the correct fiscal year integer
--   e.g. DATE_ADD("2020-09-01", INTERVAL 4 MONTH)
--        = "2021-01-01" → YEAR() = 2021 ✓
--   e.g. DATE_ADD("2021-08-31", INTERVAL 4 MONTH)
--        = "2021-12-31" → YEAR() = 2021 ✓
--   e.g. DATE_ADD("2021-09-01", INTERVAL 4 MONTH)
--        = "2022-01-01" → YEAR() = 2022 ✓
-- DETERMINISTIC: declared because same input date always
--   returns same fiscal year — allows MySQL query optimizer
--   to cache results and improve performance
-- Important architectural note:
--   This function is used directly in get_market_badge_sp.sql
--   All other SPs in this repository use JOIN on dim_date
--   instead — preferred approach for set-based queries
--   as it avoids row-by-row function evaluation
-- Used by:
--   03_stored_procedures/get_market_badge_sp.sql
--   03_stored_procedures/get_monthly_gross_sales_for_customer_sp.sql
--   01_gross_sales/croma_india_gross_sales_exploration.sql
-- ============================================================

DELIMITER $$

CREATE DEFINER=`root`@`localhost` FUNCTION `get_fiscal_year`(
    calendar_date DATE
) RETURNS INT
    DETERMINISTIC
BEGIN
    DECLARE fiscal_year INT;

    -- Add 4 months to shift September → January,
    -- then extract the year to get the fiscal year integer
    SET fiscal_year = YEAR(DATE_ADD(calendar_date, INTERVAL 4 MONTH));

    RETURN fiscal_year;
END$$

DELIMITER ;
