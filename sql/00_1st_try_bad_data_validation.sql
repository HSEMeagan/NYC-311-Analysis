-- NYC 311 Service Requests Analysis
-- Data validation

-- 1. Confirm total number of records
SELECT COUNT(*) AS total_rows
FROM service_requests;

-- Result: 3,450,000 rows


-- 2. Inspect table structure

PRAGMA table_info(service_requests);

-- Every column is 'text', no numerics 


-- 3. Check date range

SELECT
    MIN(created_date) AS earliest_request,
    MAX(created_date) AS latest_request
FROM service_requests;

-- Result:
-- Earliest: 2020-01-01
-- Latest: 2025-10-31


-- 4. Check for duplicate request IDs

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT unique_key) AS unique_requests
FROM service_requests;

-- Result:
-- Total rows: 3,450,000
-- Unique requests: 3,450,000
-- No duplicate request IDs found.


-- 5. Check missing values in key fields

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN created_date IS NULL OR created_date = '' THEN 1 ELSE 0 END) AS missing_created_date,
    SUM(CASE WHEN closed_date IS NULL OR closed_date = '' THEN 1 ELSE 0 END) AS missing_closed_date,
    SUM(CASE WHEN complaint_type IS NULL OR complaint_type = '' THEN 1 ELSE 0 END) AS missing_complaint_type,
    SUM(CASE WHEN borough IS NULL OR borough = '' THEN 1 ELSE 0 END) AS missing_borough,
    SUM(CASE WHEN status IS NULL OR status = '' THEN 1 ELSE 0 END) AS missing_status
FROM service_requests;

-- Results:
-- Missing created_date: 0
-- Missing closed_date: 40,945
-- Missing complaint_type: 0
-- Missing borough: 31,997
-- Missing status: 0


-- 6. Check request statuses

SELECT
    status,
    COUNT(*) AS request_count
FROM service_requests
GROUP BY status
ORDER BY request_count DESC;

-- Results:
-- Closed: 3,385,628
-- In Progress: 34,468
-- Pending: 25,101
-- Open: 2,248
-- Assigned: 1,975
-- Started: 576
-- Unspecified: 3
-- Cancel: 1


-- 7. Compare status with closed date availability

SELECT
    status,
    COUNT(*) AS total_requests,
    SUM(
        CASE
            WHEN closed_date IS NULL OR closed_date = '' THEN 1
            ELSE 0
        END
    ) AS missing_closed_date
FROM service_requests
GROUP BY status
ORDER BY total_requests DESC;

-- Observation:
-- Missing closed dates are primarily associated with requests
-- that are not closed. Only 3 requests have a "Closed" status
-- but no closed date.

------------------------------------------------------------------------

-- Check distribution of records across months
SELECT
    substr(created_date, 1, 7) AS year_month,
    COUNT(*) AS request_count
FROM service_requests
GROUP BY year_month
ORDER BY year_month;

/*
Initial data exploration revealed that the original 3.45 million-row
download was not evenly distributed across the intended 2020–2025
timeframe. Records were concentrated primarily in 2020 and early 2021,
with 2022–2024 absent.

Because this distribution would bias temporal and seasonal analysis,
the original dataset was not used for the final analysis. The data
collection approach was revised to include complete representative
months across multiple years.
*/
