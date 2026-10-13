-- NYC 311 Service Requests Analysis
-- EDA

-- Dataset: NYC 311 Service Requests (2020-2026)
-- Records: 1,399,950
-- Source: NYC Open Data
-- Method: Stratified sampling by month and borough
-- Analysis table: service_requests_clean

-- Sampling limitation:
-- Monthly sample sizes were set during extraction.
-- Raw sample counts do not represent actual NYC request volumes.
-- Interpret borough and time comparisons cautiously.



-- 1. Understanding sample


-- 1.1 examine by year and month

SELECT
    created_year,
    created_month,
    COUNT(*) AS sampled_requests
FROM service_requests_clean
GROUP BY created_year, created_month
ORDER BY created_year, created_month;

-- All 81 months represented (Jan 2020-Sep 2026)
-- 2020-2025: 16,666 requests per month
-- 2026: 22,222 requests per month
-- Monthly counts reflect extraction quotas, not actual request volume


-- 1.2 examine distribution by borough

SELECT
    COALESCE(borough, 'Missing') AS borough,
    COUNT(*) AS sampled_requests,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM service_requests_clean),
        2
    ) AS pct_of_sample
FROM service_requests_clean
GROUP BY borough
ORDER BY sampled_requests DESC;

-- Brooklyn has the largest sample share (30.04%)
-- Staten Island has the smallest (4.25%)
-- Unspecified: 3,061; missing borough: 2,393
-- Borough proportions may reflect the sampling method

-- 1.3 examine borough distribution by year

SELECT
    created_year,
    COALESCE(borough, 'Missing') AS borough,
    COUNT(*) AS sampled_requests,
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY created_year),
        2
    ) AS pct_of_year_sample
FROM service_requests_clean
GROUP BY created_year, borough
ORDER BY created_year, sampled_requests DESC;

-- Brooklyn consistently has the largest sample share (~29-31%).
-- Borough proportions remain relatively stable across years.
-- Missing and unspecified borough values decline after 2020.
-- Geographic comparisons remain subject to sampling limitations.


-- 1.4 Examine complaint-type coverage by year

SELECT
    created_year,
    COUNT(DISTINCT complaint_type_clean) AS distinct_complaint_types,
    COUNT(*) AS sampled_requests
FROM service_requests_clean
GROUP BY created_year
ORDER BY created_year;

-- Complaint-type coverage ranges from 167 to 185 categories.
-- 2021 has the most categories (185); 2020 has the fewest (167).
-- Variation may reflect classification changes or sample coverage.
-- Annual counts reflect sampling quotas, not actual NYC volume.

-- 1.5 Examine complaint-type consistency across years

SELECT
    complaint_type_clean,
    COUNT(DISTINCT created_year) AS years_present,
    MIN(created_year) AS first_year,
    MAX(created_year) AS last_year,
    COUNT(*) AS sampled_requests
FROM service_requests_clean
GROUP BY complaint_type_clean
ORDER BY years_present ASC, sampled_requests DESC;

-- Major complaint types are represented in all seven years.
-- Some categories appear only during specific periods.
-- Limited coverage may reflect classification or sampling changes.
-- Preserve original category distinctions in trend comparisons.





-- 1.6 Summarize complaint-type coverage across years

WITH complaint_coverage AS (
    SELECT
        complaint_type_clean,
        COUNT(DISTINCT created_year) AS years_present
    FROM service_requests_clean
    GROUP BY complaint_type_clean
)
SELECT
    years_present,
    COUNT(*) AS complaint_types
FROM complaint_coverage
GROUP BY years_present
ORDER BY years_present; 

-- 129 complaint types appear in all seven years.
-- 94 complaint types appear in fewer than seven years.
-- Category coverage varies, so year-to-year comparisons require caution.



---------------------------------------------------------------
-- 2. Complaint type analysis
---------------------------------------------------------------

-- 2.1 Identify the 10 most common complaint types

SELECT
    complaint_type_clean,
    COUNT(*) AS total_requests,
    ROUND(
        COUNT(*) * 100.0 / 1399950,
        2
    ) AS pct_of_sample
FROM service_requests_clean
GROUP BY complaint_type_clean
ORDER BY total_requests DESC
LIMIT 10;

-- Illegal Parking is the most common complaint (12.95%).
-- Noise - Residential ranks second (11.33%).
-- Top 5 complaint types account for 41.33% of sampled requests.
-- Noise complaints appear in 3 of the top 10 categories.

