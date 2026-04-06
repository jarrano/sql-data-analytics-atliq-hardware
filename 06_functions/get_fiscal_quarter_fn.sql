-- ============================================================
-- Function: get_fiscal_quarter
-- Database: gdb0041 (AtliQ Hardware)
-- Purpose: Convert a calendar date to its corresponding
--          AtliQ Hardware fiscal quarter label
-- Parameter:
--   calendar_date (DATE) — any calendar date
-- Returns: CHAR(2) — fiscal quarter label e.g. "Q1", "Q2"
-- Fiscal quarter definition (September start):
--   Q1 → Sep, Oct, Nov
--   Q2 → Dec, Jan, Feb
--   Q3 → Mar, Apr, May
--   Q4 → Jun, Jul, Aug
-- Logic: Same 4-month shift as get_fiscal_year_fn.sql
--   ADD 4 months to align September → January (Q1 start)
--   QUARTER() extracts the quarter number (1–4)
--   CONCAT('Q', number) produces the label "Q1"–"Q4"
--   e.g. DATE_ADD("2020-09-15", INTERVAL 4 MONTH)
--        = "2021-01-15" → QUARTER() = 1 → "Q1" ✓
--   e.g. DATE_ADD("2020-12-15", INTERVAL 4 MONTH)
--        = "2021-04-15" → QUARTER() = 2 → "Q2" ✓
--   e.g. DATE_ADD("2021-06-15", INTERVAL 4 MONTH)
--        = "2021-10-15" → QUARTER() = 4 → "Q4" ✓
-- DETERMINISTIC: same input always returns same output —
--   allows MySQL optimizer to cache results
-- Implementation details:
--   DECLARE number_quarter TINYINT — TINYINT sufficient
--   for values 1–4; minimal memory footprint
--   DECLARE fiscal_quarter CHAR(2) — fixed 2-char output
--   CHARSET utf8mb4 on return type — consistent with
--   database default character set
-- Relationship to get_fiscal_year:
--   Both functions use the same 4-month shift logic
--   get_fiscal_year  → extracts YEAR()    → returns INT
--   get_fiscal_quarter → extracts QUARTER() → returns CHAR(2)
--   Parallel design makes both functions predictable
--   and easy to maintain together
-- ============================================================

DELIMITER $$

CREATE DEFINER=`root`@`localhost` FUNCTION `get_fiscal_quarter`(
    calendar_date DATE
) RETURNS CHAR(2) CHARSET utf8mb4
    DETERMINISTIC
BEGIN
    DECLARE number_quarter  TINYINT;
    DECLARE fiscal_quarter  CHAR(2);

    -- Same 4-month shift as get_fiscal_year
    -- QUARTER() returns 1-4 based on shifted date
    SET number_quarter = QUARTER(DATE_ADD(calendar_date, INTERVAL 4 MONTH));

    -- Concatenate 'Q' prefix to produce label e.g. "Q1"
    SET fiscal_quarter = CONCAT('Q', number_quarter);

    RETURN fiscal_quarter;
END$$

DELIMITER ;
