-- Preppin' Data 2023 Week 01 Solution
-- Source: TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK01
--
-- Transformations applied:
--   - Extract leading letters from TRANSACTION_CODE as the Bank
--   - Rename ONLINE_OR_IN_PERSON: 1 = 'Online', 2 = 'In-Person'
--   - Convert TRANSACTION_DATE to day of week
--
-- Three outputs at different levels of detail:
--   1. Total values of transactions by each bank
--   2. Total values by bank, day of the week, and type of transaction
--   3. Total values by bank and customer code

-- Output 1: Total values by bank
WITH base AS (
    SELECT
        REGEXP_SUBSTR(TRANSACTION_CODE, '^[A-Za-z]+') AS Bank,
        VALUE,
        CASE ONLINE_OR_IN_PERSON
            WHEN 1 THEN 'Online'
            WHEN 2 THEN 'In-Person'
        END AS Online_or_In_Person,
        DAYNAME(TO_DATE(TRANSACTION_DATE, 'DD/MM/YYYY HH24:MI:SS')) AS Day_of_Week,
        CUSTOMER_CODE
    FROM TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK01
)
SELECT
    Bank,
    SUM(VALUE) AS Total_Value
FROM base
GROUP BY Bank;

-- Output 2: Total values by bank, day of week, and transaction type
WITH base AS (
    SELECT
        REGEXP_SUBSTR(TRANSACTION_CODE, '^[A-Za-z]+') AS Bank,
        VALUE,
        CASE ONLINE_OR_IN_PERSON
            WHEN 1 THEN 'Online'
            WHEN 2 THEN 'In-Person'
        END AS Online_or_In_Person,
        DAYNAME(TO_DATE(TRANSACTION_DATE, 'DD/MM/YYYY HH24:MI:SS')) AS Day_of_Week,
        CUSTOMER_CODE
    FROM TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK01
)
SELECT
    Bank,
    Day_of_Week,
    Online_or_In_Person,
    SUM(VALUE) AS Total_Value
FROM base
GROUP BY Bank, Day_of_Week, Online_or_In_Person;

-- Output 3: Total values by bank and customer code
WITH base AS (
    SELECT
        REGEXP_SUBSTR(TRANSACTION_CODE, '^[A-Za-z]+') AS Bank,
        VALUE,
        CASE ONLINE_OR_IN_PERSON
            WHEN 1 THEN 'Online'
            WHEN 2 THEN 'In-Person'
        END AS Online_or_In_Person,
        DAYNAME(TO_DATE(TRANSACTION_DATE, 'DD/MM/YYYY HH24:MI:SS')) AS Day_of_Week,
        CUSTOMER_CODE
    FROM TIL_PLAYGROUND.PREPPIN_DATA_INPUTS.PD2023_WK01
)
SELECT
    Bank,
    CUSTOMER_CODE,
    SUM(VALUE) AS Total_Value
FROM base
GROUP BY Bank, CUSTOMER_CODE;
