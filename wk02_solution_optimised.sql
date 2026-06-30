-- ============================================================
-- PD2023 Week 2: IBAN Construction (production-hardened)
-- ============================================================

-- Step 1: Assertions — pipeline should FAIL if any of these return rows
-- Run these first; if any return results, do NOT proceed.

-- 1a. Unmatched banks (rows that would be silently dropped by join)
SELECT 'UNMATCHED_BANK' AS check_name, t.TRANSACTION_ID, t.BANK
FROM TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK02_TRANSACTIONS t
LEFT JOIN TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK02_SWIFT_CODES s
    ON UPPER(TRIM(t.BANK)) = UPPER(TRIM(s.BANK))
WHERE s.BANK IS NULL;

-- 1b. Invalid sort codes (not 6 digits after cleaning)
SELECT 'INVALID_SORT_CODE' AS check_name, TRANSACTION_ID, SORT_CODE
FROM TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK02_TRANSACTIONS
WHERE REGEXP_REPLACE(TRIM(SORT_CODE), '[^0-9]', '') NOT RLIKE '^[0-9]{6}$';

-- 1c. Invalid account numbers (not 8 digits when zero-padded)
SELECT 'INVALID_ACCOUNT_NUMBER' AS check_name, TRANSACTION_ID, ACCOUNT_NUMBER
FROM TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK02_TRANSACTIONS
WHERE ACCOUNT_NUMBER IS NULL
   OR ACCOUNT_NUMBER < 0
   OR ACCOUNT_NUMBER > 99999999;

-- 1d. Invalid SWIFT lookup entries
SELECT 'INVALID_SWIFT_LOOKUP' AS check_name, BANK, SWIFT_CODE, CHECK_DIGITS
FROM TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK02_SWIFT_CODES
WHERE LENGTH(TRIM(SWIFT_CODE)) != 4
   OR LENGTH(TRIM(CHECK_DIGITS)) != 2;

-- 1e. Duplicate transaction IDs (would cause fan-out)
SELECT 'DUPLICATE_TRANSACTION_ID' AS check_name, TRANSACTION_ID, COUNT(*) AS cnt
FROM TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK02_TRANSACTIONS
GROUP BY TRANSACTION_ID
HAVING COUNT(*) > 1;

-- 1f. Duplicate banks in SWIFT lookup (would cause fan-out on join)
SELECT 'DUPLICATE_SWIFT_BANK' AS check_name, BANK, COUNT(*) AS cnt
FROM TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK02_SWIFT_CODES
GROUP BY BANK
HAVING COUNT(*) > 1;

-- 1g. Row count bounds (adjust thresholds to your expected range)
SELECT 'ROW_COUNT_OUT_OF_BOUNDS' AS check_name, COUNT(*) AS row_count
FROM TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK02_TRANSACTIONS
HAVING COUNT(*) NOT BETWEEN 50 AND 200;


-- ============================================================
-- Step 2: Build IBANs with hardened logic
-- ============================================================
WITH cleaned AS (
    SELECT
        t.TRANSACTION_ID,
        TRIM(t.BANK)                                        AS bank_clean,
        REGEXP_REPLACE(TRIM(t.SORT_CODE), '[^0-9]', '')     AS sort_code_clean,
        LPAD(TO_VARCHAR(t.ACCOUNT_NUMBER), 8, '0')          AS account_number_clean,
        TRIM(s.SWIFT_CODE)                                  AS swift_code,
        TRIM(s.CHECK_DIGITS)                                AS check_digits,
        -- Validation flags
        CASE WHEN s.BANK IS NULL THEN 1 ELSE 0 END         AS is_unmatched,
        CASE WHEN REGEXP_REPLACE(TRIM(t.SORT_CODE), '[^0-9]', '') NOT RLIKE '^[0-9]{6}$'
             THEN 1 ELSE 0 END                              AS is_bad_sort_code,
        CASE WHEN t.ACCOUNT_NUMBER IS NULL
              OR t.ACCOUNT_NUMBER < 0
              OR t.ACCOUNT_NUMBER > 99999999
             THEN 1 ELSE 0 END                              AS is_bad_account
    FROM TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK02_TRANSACTIONS t
    LEFT JOIN TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK02_SWIFT_CODES s
        ON UPPER(TRIM(t.BANK)) = UPPER(TRIM(s.BANK))
)

SELECT
    TRANSACTION_ID,
    CASE
        WHEN is_unmatched = 1 OR is_bad_sort_code = 1 OR is_bad_account = 1
        THEN NULL  -- explicitly NULL rather than a malformed IBAN
        ELSE 'GB' || check_digits || swift_code || sort_code_clean || account_number_clean
    END AS IBAN,
    -- Error column: tells you WHY a row failed (NULL if valid)
    NULLIF(
        IFF(is_unmatched = 1, 'UNMATCHED_BANK; ', '')
        || IFF(is_bad_sort_code = 1, 'INVALID_SORT_CODE; ', '')
        || IFF(is_bad_account = 1, 'INVALID_ACCOUNT_NUMBER; ', ''),
        ''
    ) AS rejection_reason
FROM cleaned
ORDER BY TRANSACTION_ID;
