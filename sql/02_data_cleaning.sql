-- NYC 311 Service Requests Analysis
-- Data cleaning

-- 1. Create an analysis table from the raw data
CREATE TABLE service_requests_clean AS
SELECT *
FROM service_requests;

-----------------------------------------------------
-- Tentative columns to clean for analysis:
--      Request: unique_key, complaint_type, descriptor, agency, status
--      Time: created_date, closed_date
--      Geography: borough, incident_zip, city, latitude/longitude
-----------------------------------------------------



-- 2. adjust format of dates, currently strings
--      a. add standardized fields  

ALTER TABLE service_requests_clean
ADD COLUMN created_datetime TEXT;

ALTER TABLE service_requests_clean
ADD COLUMN closed_datetime TEXT;

--      b. fill with dates 

UPDATE service_requests_clean
SET created_datetime = datetime(
    REPLACE(created_date, 'T', ' ')
);

UPDATE service_requests_clean
SET closed_datetime = datetime(
    REPLACE(closed_date, 'T', ' ')
)
WHERE closed_date IS NOT NULL
    AND closed_date <> '';


--      c. check that none got missed | created then closing dates

SELECT COUNT(*) AS failed_created_conversion
FROM service_requests_clean
WHERE created_date IS NOT NULL
    AND created_date <> ''
    AND created_datetime IS NULL;

SELECT COUNT(*) AS failed_closed_conversion
FROM service_requests_clean
WHERE closed_date IS NOT NULL
    AND closed_date <> ''
    AND closed_datetime IS NULL;


-- 3. Add time-analysis columns 

--      a. create columns 
ALTER TABLE service_requests_clean
ADD COLUMN created_year INTEGER;

ALTER TABLE service_requests_clean
ADD COLUMN created_month INTEGER;

ALTER TABLE service_requests_clean
ADD COLUMN created_day_of_week TEXT;

ALTER TABLE service_requests_clean
ADD COLUMN created_hour INTEGER;

ALTER TABLE service_requests_clean
ADD COLUMN created_season TEXT;

--      b. fill them with correct data

UPDATE service_requests_clean
SET
    created_year = CAST(strftime('%Y', created_datetime) AS INTEGER),

    created_month = CAST(strftime('%m', created_datetime) AS INTEGER),

    created_day_of_week =
        CASE strftime('%w', created_datetime)
            WHEN '0' THEN 'Sunday'
            WHEN '1' THEN 'Monday'
            WHEN '2' THEN 'Tuesday'
            WHEN '3' THEN 'Wednesday'
            WHEN '4' THEN 'Thursday'
            WHEN '5' THEN 'Friday'
            WHEN '6' THEN 'Saturday'
        END,

    created_hour = CAST(strftime('%H', created_datetime) AS INTEGER),

    created_season =
        CASE
            WHEN CAST(strftime('%m', created_datetime) AS INTEGER) IN (12, 1, 2)
                THEN 'Winter'
            WHEN CAST(strftime('%m', created_datetime) AS INTEGER) IN (3, 4, 5)
                THEN 'Spring'
            WHEN CAST(strftime('%m', created_datetime) AS INTEGER) IN (6, 7, 8)
                THEN 'Summer'
            WHEN CAST(strftime('%m', created_datetime) AS INTEGER) IN (9, 10, 11)
                THEN 'Fall'
        END;

--      c. check unique values
SELECT DISTINCT created_year
FROM service_requests_clean
ORDER BY created_year;
-- 2020–2026

SELECT DISTINCT created_month
FROM service_requests_clean
ORDER BY created_month;
-- 1-12

SELECT DISTINCT created_day_of_week
FROM service_requests_clean;
-- sunday- Saturday

SELECT DISTINCT created_hour
FROM service_requests_clean
ORDER BY created_hour;
-- 0-23

SELECT DISTINCT created_season
FROM service_requests_clean;
-- winter, spring, fall, summer

--      d. last validation that everything got added/changed
SELECT
    SUM(CASE WHEN created_year IS NULL THEN 1 ELSE 0 END) AS missing_year,
    SUM(CASE WHEN created_month IS NULL THEN 1 ELSE 0 END) AS missing_month,
    SUM(CASE WHEN created_day_of_week IS NULL THEN 1 ELSE 0 END) AS missing_day,
    SUM(CASE WHEN created_hour IS NULL THEN 1 ELSE 0 END) AS missing_hour,
    SUM(CASE WHEN created_season IS NULL THEN 1 ELSE 0 END) AS missing_season
FROM service_requests_clean;
-- all zeros ! 


-- 4. validate/clean status column 
--      a. check possible values
SELECT
    status,
    COUNT(*) AS request_count
FROM service_requests_clean
GROUP BY status
ORDER BY request_count DESC;

--      b. trim leading/trailing whitespace
SELECT
    UPPER(TRIM(status)) AS standardized_status,
    COUNT(*) AS request_count
FROM service_requests_clean
GROUP BY UPPER(TRIM(status))
ORDER BY request_count DESC;

--      c. find closed that have no closed date
SELECT COUNT(*) AS closed_without_closed_date
FROM service_requests_clean
WHERE status = 'Closed'
    AND (
        closed_datetime IS NULL
        OR closed_datetime = ''
    );

------------------------------------------------------------------------
-- Status required minimal cleaning. Seven valid status categories were
-- identified, with no missing values. TRIM() was applied to remove
-- potential leading or trailing whitespace.

-- 3067 records marked 'Closed' do not contain a closed date. These
-- records were retained, but they will be excluded from analyses that
-- require a calculable resolution time.
------------------------------------------------------------------------

-- 5. Clean and validate borough
--      a. check possible values and count
SELECT
    borough,
    COUNT(*) AS request_count
FROM service_requests_clean
GROUP BY borough
ORDER BY request_count DESC;

--      b. investigate missing boroughs 

SELECT
    borough,
    city,
    incident_zip,
    COUNT(*) AS request_count
FROM service_requests_clean
WHERE incident_zip IS NULL
GROUP BY borough, city, incident_zip
ORDER BY request_count DESC;

-- if borough is missing, the other columns are missing 
-- there is chance of data in borough and city if the zip is missing (19 rows returned)
-- there is a higher likelihood of data in borough and zip even if th city is missing (211 rows returned) 

--      c. convert empty strings to 'null's 
UPDATE service_requests_clean
SET borough = NULL
WHERE borough = '';

SELECT
    borough,
    COUNT(*) AS request_count
FROM service_requests_clean
GROUP BY borough
ORDER BY request_count DESC;

-- BROOKLYN	        420582
-- QUEENS	        340086
-- BRONX	        294172
-- MANHATTAN	    280107
-- STATEN ISLAND	59549
-- Unspecified	    3061
-- [NULL]	        2393

------------------------------------------------------------------------
-- Records with missing borough values were investigated using city,
-- ZIP code, and other geographic fields. Missing borough records did
-- not contain sufficient geographic information to reliably infer a
-- borough, so these values were retained as NULL rather than imputed.

-- Records with a valid borough were retained even when city or ZIP
-- code was missing, since borough remains usable for borough-level
-- analysis.
------------------------------------------------------------------------


-- 5. Investigate Borough 
--      a. check possible values and distribution
select complaint_type, count(*) as count
from service_requests_clean
group by complaint_type
order by complaint_type;


--      b. count distinct values 
select count(distinct(complaint_type))
from service_requests_clean src ;
-- 229

--      c. check which values are fixed by trim white space and capitalization
SELECT
    UPPER(TRIM(complaint_type)) AS standardized_type,
    COUNT(DISTINCT complaint_type) AS original_variations,
    GROUP_CONCAT(DISTINCT complaint_type) AS variations,
    COUNT(*) AS total_requests
FROM service_requests_clean
GROUP BY UPPER(TRIM(complaint_type))
HAVING COUNT(DISTINCT complaint_type) > 1
ORDER BY total_requests DESC;

-- PLUMBING	2	Plumbing,PLUMBING	25750
-- ELEVATOR	2	Elevator,ELEVATOR	8249


--      d. investigate complaint category possible duplicates 

SELECT
    created_year,
    complaint_type,
    COUNT(*) AS request_count
FROM service_requests_clean
WHERE complaint_type IN (
    'Dirty Condition',
    'Dirty Conditions',
    'ELECTRIC',
    'Electrical',
    'ELEVATOR',
    'Elevator',
    'Hazardous Material',
    'Hazardous Materials',
    'Litter Basket Request',
    'Litter Basket / Request',
    'Missed Collection',
    'Missed Collection (All Materials)',
    'PLUMBING',
    'Plumbing',
    'Smoking',
    'Smoking or Vaping',
    'Snow',
    'Snow or Ice'
)
GROUP BY created_year, complaint_type
ORDER BY complaint_type, created_year;


--      e. create column for standardized complaint type and clean the columns
--          based on capitalization and taxonomy changes
ALTER TABLE service_requests_clean
ADD COLUMN complaint_type_clean TEXT;

UPDATE service_requests_clean
SET complaint_type_clean =
    CASE
        WHEN TRIM(complaint_type) = 'ELEVATOR'
            THEN 'Elevator'
        WHEN TRIM(complaint_type) = 'PLUMBING'
            THEN 'Plumbing'
        WHEN TRIM(complaint_type) = 'Dirty Conditions'
            THEN 'Dirty Condition'
        WHEN TRIM(complaint_type) = 'Litter Basket / Request'
            THEN 'Litter Basket Request'
        WHEN TRIM(complaint_type) = 'Missed Collection (All Materials)'
            THEN 'Missed Collection'
        WHEN TRIM(complaint_type) = 'Snow'
            THEN 'Snow or Ice'
        ELSE TRIM(complaint_type)
    END;

--      f. validation
SELECT
    COUNT(DISTINCT complaint_type) AS original_categories,
    COUNT(DISTINCT complaint_type_clean) AS cleaned_categories
FROM service_requests_clean;
-- diff = 6 as expected


-------------------------------------------------------------------------
-- Complaint types were reviewed for capitalization differences,
-- formatting inconsistencies, and changes in terminology across years.

-- The following categories were standardized in complaint_type_clean:

-- Capitalization differences:
-- - ELEVATOR -> Elevator
-- - PLUMBING -> Plumbing

-- Terminology changes identified through year-by-year comparison:
-- - Dirty Conditions -> Dirty Condition
-- - Litter Basket / Request -> Litter Basket Request
-- - Missed Collection (All Materials) -> Missed Collection
-- - Snow -> Snow or Ice

-- Similar-looking categories were not automatically combined when the
-- difference could represent a meaningful distinction in NYC's complaint
-- classification.

-- For example:
-- - ELECTRIC and Electrical were retained separately because they use
--   different terminology and both appear throughout the dataset.
-- - Smoking and Smoking or Vaping were retained separately because the
--   latter represents a broader complaint category and the two overlap
--   across multiple years.
-- - Hazardous Material and Hazardous Materials were retained separately
--   because the singular category appears alongside the existing plural
--   category rather than clearly replacing it.
-- - Damaged, dangling, and missing sign complaints were retained as
--   separate categories because they describe different conditions.

-- The original complaint_type field was preserved. A separate
-- complaint_type_clean field was created so that the original NYC
-- classification remains available for reference.

-------------------------------------------------------------------------



-- 6. Investigate agency column 

--      a. Check agency distribution
SELECT
    agency,
    COUNT(*) AS request_count
FROM service_requests_clean
GROUP BY agency
ORDER BY request_count DESC;
-- 20 agencies; NYPD highest (614,686), NYC311-PRD lowest (13).

--      b. capitalization and whitespace inconsistencies
SELECT
    COUNT(DISTINCT agency) AS original_agencies,
    COUNT(DISTINCT UPPER(TRIM(agency))) AS standardized_agencies
FROM service_requests_clean;
-- 20 original and 20 standardized; no difference.

--      c. Identify formatting variations
SELECT
    UPPER(TRIM(agency)) AS standardized_agency,
    COUNT(DISTINCT agency) AS original_variations,
    COUNT(*) AS request_count
FROM service_requests_clean
GROUP BY UPPER(TRIM(agency))
HAVING COUNT(DISTINCT agency) > 1
ORDER BY request_count DESC;
-- 0 rows; no capitalization or whitespace duplicates.

--      d. Check missing agency values
SELECT COUNT(*) AS missing_agency
FROM service_requests_clean
WHERE agency IS NULL
    OR TRIM(agency) = '';
-- 0 missing

-- Cleaning decision:
-- No changes needed; all 20 agency codes retained.
-- Potentially related agencies (NYCPD & NYC311-PRD) kept separate without verification.


-- 7. resolution time
--      a. Check invalid, identical, and missing closing timestamps
SELECT
    COUNT(*) AS total_requests,
    SUM(CASE WHEN closed_datetime < created_datetime THEN 1 ELSE 0 END)
        AS closed_before_created,
    SUM(CASE WHEN closed_datetime = created_datetime THEN 1 ELSE 0 END)
        AS same_created_closed_time,
    SUM(CASE WHEN closed_datetime IS NULL THEN 1 ELSE 0 END)
        AS missing_closed_datetime
FROM service_requests_clean;

-- Total: 1,399,950
-- Negative durations: 3,025
-- Identical timestamps: 29,327
-- Missing closed_datetime: 28,179


--      b. Examine negative durations by status
SELECT
    status,
    COUNT(*) AS request_count,
    ROUND(MIN(
        (julianday(closed_datetime) - julianday(created_datetime)) * 24
    ), 2) AS min_hours,
    ROUND(AVG(
        (julianday(closed_datetime) - julianday(created_datetime)) * 24
    ), 2) AS avg_hours,
    ROUND(MAX(
        (julianday(closed_datetime) - julianday(created_datetime)) * 24
    ), 2) AS max_hours
FROM service_requests_clean
WHERE closed_datetime < created_datetime
GROUP BY status
ORDER BY request_count DESC;

-- Pending: 2,876; average -124.90 hours
-- Closed: 146; average -58,655.60 hours
-- In Progress: 3; average -1,064,750.25 hours


--  c. Investigate missing original closing dates by status
SELECT
    status,
    COUNT(*) AS total
FROM service_requests_clean
WHERE closed_date IS NULL
GROUP BY status
ORDER BY total DESC;

-- In Progress: 19,402
-- Open: 4,022
-- Closed: 3,067
-- Pending: 899
-- Assigned: 489
-- Started: 297
-- Unspecified: 3
-- Closed requests without closing dates indicate inconsistencies.
-- This query checks closed_date, not closed_datetime.


--      d. Inspect extreme negative-duration records
SELECT
    unique_key,
    status,
    agency,
    complaint_type,
    created_datetime,
    closed_datetime,
    ROUND(
        (julianday(closed_datetime) - julianday(created_datetime)) * 24,
        2
    ) AS duration_hours
FROM service_requests_clean
WHERE closed_datetime < created_datetime
ORDER BY duration_hours ASC
LIMIT 30;

-- DHS records contain 1900-01-01 placeholder dates.
-- TLC records contain 1899-12-31 placeholder dates.
-- DOT/DEP records show closing dates before creation.
-- Some DOT timestamps share the same time but different dates.


--      e. Identify negative durations by agency and complaint type
SELECT
    agency,
    complaint_type,
    COUNT(*) AS negative_requests
FROM service_requests_clean
WHERE closed_datetime < created_datetime
GROUP BY agency, complaint_type
ORDER BY negative_requests DESC;

-- DOT Street Light Condition accounts for 94.9% of negatives.


--      f. Examine negative durations by creation year and status
SELECT
    created_year,
    status,
    COUNT(*) AS negative_requests
FROM service_requests_clean
WHERE closed_datetime < created_datetime
GROUP BY created_year, status
ORDER BY created_year, status;

-- Negative durations occur across all years (2020-2026).


--      g. Investigate DOT Street Light Condition negative durations
SELECT
    status,
    COUNT(*) AS negative_requests,
    ROUND(MIN(
        (julianday(closed_datetime) - julianday(created_datetime)) * 24
    ), 2) AS min_hours,
    ROUND(AVG(
        (julianday(closed_datetime) - julianday(created_datetime)) * 24
    ), 2) AS avg_hours,
    ROUND(MAX(
        (julianday(closed_datetime) - julianday(created_datetime)) * 24
    ), 2) AS max_hours
FROM service_requests_clean
WHERE agency = 'DOT'
    AND complaint_type = 'Street Light Condition'
    AND closed_datetime < created_datetime
GROUP BY status;

-- All 2,870 records are Pending.
-- Minimum: -8,808 hours
-- Average: -118.41 hours
-- Maximum: -24.02 hours


--      h. Investigate negative durations among Closed requests
SELECT
    CASE
        WHEN closed_datetime < '2000-01-01'
            THEN 'Placeholder or historical date'
        ELSE 'Other negative duration'
    END AS issue_type,
    agency,
    COUNT(*) AS request_count
FROM service_requests_clean
WHERE status = 'Closed'
    AND closed_datetime < created_datetime
GROUP BY issue_type, agency
ORDER BY request_count DESC;

-- Other negative duration:
-- NYPD: 95
-- DEP: 31
-- DOT: 12
-- Placeholder or historical date:
-- DHS: 8
-- Total: 146 Closed requests with negative durations.


-- Cleaning decision

-- keep all records and preserve original timestamps.
-- Exclude negative durations from resolution-time calculations.
-- Calculate resolution time only for Closed requests with
-- valid creation and closing timestamps.
-- Unresolved, missing, or invalid durations will remain NULL.


--      i. calculate relosution time for valid closed requests
--            1. make column 

ALTER TABLE service_requests_clean
ADD COLUMN resolution_hours REAL;

--            2. fill column 
UPDATE service_requests_clean
SET resolution_hours =
    ROUND(
        (julianday(closed_datetime) -
         julianday(created_datetime)) * 24,
        2
    )
WHERE status = 'Closed'
    AND created_datetime IS NOT NULL
    AND closed_datetime IS NOT NULL
    AND closed_datetime >= created_datetime;

--      j. validate resolution time

SELECT
    COUNT(resolution_hours) AS valid_resolution_times,
    SUM(CASE WHEN resolution_hours < 0 THEN 1 ELSE 0 END)
        AS negative_resolution_times,
    SUM(CASE WHEN resolution_hours IS NULL THEN 1 ELSE 0 END)
        AS excluded_requests,
    ROUND(AVG(resolution_hours), 2) AS avg_resolution_hours
FROM service_requests_clean;
-- valid resolutions:          1366401	
-- negative resolution times:  0	
-- exclluded requests:         33549	
-- average resolution time:    469.24


--      k. Examine resolution time distribution


SELECT
    COUNT(resolution_hours) AS valid_requests,
    ROUND(MIN(resolution_hours), 2) AS min_hours,
    ROUND(AVG(resolution_hours), 2) AS avg_hours,
    ROUND(MAX(resolution_hours), 2) AS max_hours
FROM service_requests_clean;

-- 1,366,401 valid resolutions.
-- Minimum: 0 hours; average: 469.24; maximum: 56,544.4 hours.

--      l. group resolutiont times into duration ranges
SELECT
    CASE
        WHEN resolution_hours < 24 THEN 'Under 1 day'
        WHEN resolution_hours < 168 THEN '1-7 days'
        WHEN resolution_hours < 720 THEN '7-30 days'
        WHEN resolution_hours < 2160 THEN '30-90 days'
        ELSE 'Over 90 days'
    END AS resolution_range,
    COUNT(*) AS request_count
FROM service_requests_clean
WHERE resolution_hours IS NOT NULL
GROUP BY resolution_range
ORDER BY MIN(resolution_hours);

-- Under 1 day: 798,463 (58.4%)
-- 1-7 days: 318,184 (23.3%)
-- 7-30 days: 139,114 (10.2%)
-- 30-90 days: 60,414 (4.4%)
-- Over 90 days: 50,226 (3.7%)
-- Most requests (81.7%) closed within 7 days.


--      m. inspect longest resolution times
SELECT
    unique_key,
    agency,
    complaint_type,
    created_datetime,
    closed_datetime,
    resolution_hours,
    ROUND(resolution_hours / 24.0, 1) AS resolution_days
FROM service_requests_clean
WHERE resolution_hours IS NOT NULL
ORDER BY resolution_hours DESC
LIMIT 20;

-- Maximum recorded duration: 2,356 days (~6.45 years).
-- Long durations include DOT, DOB, DEP, and DPR requests.
-- Several DEP Water System requests share closing timestamps.
-- Additional inspection of 200 records found many New Tree Requests.


--      n. investigate results over one year

SELECT
    agency,
    complaint_type,
    COUNT(*) AS requests_over_1_year,
    ROUND(AVG(resolution_hours / 24.0), 1)
        AS avg_resolution_days,
    ROUND(MAX(resolution_hours / 24.0), 1)
        AS max_resolution_days
FROM service_requests_clean
WHERE resolution_hours > 365 * 24
GROUP BY agency, complaint_type
ORDER BY requests_over_1_year DESC
LIMIT 20;

-- Highest counts:
-- DPR / New Tree Request: 3,272
-- EDC / Noise - Helicopter: 3,016
-- DOHMH / Food Establishment: 2,034
-- DPR / Overgrown Tree/Branches: 1,369
-- DPR / Damaged Tree: 1,035
-- Long durations are concentrated in certain complaint types.
-- Averages apply only to requests exceeding one year.


--      o. check repeated dep closing timestamps

SELECT
    closed_datetime,
    COUNT(*) AS requests_closed
FROM service_requests_clean
WHERE agency = 'DEP'
    AND complaint_type = 'Water System'
    AND resolution_hours > 365 * 24
GROUP BY closed_datetime
HAVING COUNT(*) > 1
ORDER BY requests_closed DESC
LIMIT 20;

-- 2026-07-08 13:00:00: 16 requests
-- 2026-07-15 10:00:00: 8 requests
-- 2026-05-28 14:30:00: 6 requests
-- Repeated timestamps may indicate administrative batch closures.
-- Actual reason for simultaneous closures is unconfirmed.


--      p. final resolution time validation

SELECT
    COUNT(*) AS valid_resolutions,
    SUM(CASE WHEN resolution_hours = 0 THEN 1 ELSE 0 END)
        AS zero_hour_resolutions,
    SUM(CASE WHEN resolution_hours > 365 * 24 THEN 1 ELSE 0 END)
        AS over_one_year,
    ROUND(AVG(resolution_hours), 2) AS avg_hours
FROM service_requests_clean
WHERE resolution_hours IS NOT NULL;

-- Valid resolutions: 1,366,401
-- Zero-hour resolutions: 28,781 (2.1%)
-- Over one year: 17,883 (1.3%)
-- Average: 469.24 hours (~19.6 days)




---------------------------------------------------------------
-- FINAL CLEANING DECISION:

-- Retain zero-hour and long-duration records.
-- No evidence sufficient to justify removing positive outliers.
-- Preserve original creation and closing timestamps.
-- Resolution hours calculated only for Closed requests
-- with valid, nonnegative durations.
-- NULL indicates unavailable or inapplicable resolution time.
-- Recorded closure time may differ from actual service completion.
-- Use median alongside mean during exploratory analysis.

---------------------------------------------------------------



-- 8. final cleaned dataset validation

--      a. confirm row counts and unique request id's 

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT unique_key) AS unique_requests,
    COUNT(*) - COUNT(DISTINCT unique_key) AS duplicate_ids
FROM service_requests_clean;

-- 1,399,950 rows, 1,399,950 unique IDs, 0 duplicates.

--      b. check missing values in derived columns 
select
	sum(case
			when created_datetime is null
			then 1 else 0
	end) as missing_created_datetime,
	sum(case
			when created_year is null
			then 1 else 0
	end) as missing_year,
	sum(case
			when created_month is null
			then 1 else 0
	end) as missing_month,
	sum(case
			when created_day_of_week is null
			then 1 else 0
	end) as missing_day_of_week,
	sum(case
			when created_hour is null
			then 1 else 0
	end) as missing_hour,
	sum(case
			when created_season is null
			then 1 else 0
	end) as missing_season,
	sum(case 
		when complaint_type_clean is NULL
		or trim(complaint_type_clean) = ''
		then 1 else 0
	end) as missing_complaint_type_clean
from service_requests_clean;

-- no missing values 

--      c. check derived date and time ranges

SELECT
    MIN(created_year) AS min_year,
    MAX(created_year) AS max_year,
    MIN(created_month) AS min_month,
    MAX(created_month) AS max_month,
    MIN(created_hour) AS min_hour,
    MAX(created_hour) AS max_hour,
    COUNT(DISTINCT created_day_of_week) AS distinct_days,
    COUNT(DISTINCT created_season) AS distinct_seasons
FROM service_requests_clean;
-- all ranges as expected 

--      d. check standardized complaint-type mappings
SELECT
    complaint_type,
    complaint_type_clean,
    COUNT(*) AS request_count
FROM service_requests_clean
WHERE complaint_type <> complaint_type_clean
GROUP BY complaint_type, complaint_type_clean
ORDER BY request_count DESC;
-- All 6 intended complaint-type mappings confirmed.
-- Original complaint types preserved.
-- No unexpected category changes detected.

--      e. Validate resolution-time consistency

SELECT
    SUM(CASE
        WHEN resolution_hours IS NOT NULL
        AND (
            status <> 'Closed'
            OR created_datetime IS NULL
            OR closed_datetime IS NULL
            OR closed_datetime < created_datetime
        )
        THEN 1 ELSE 0
    END) AS invalid_populated_resolutions,
    SUM(CASE
        WHEN status = 'Closed'
        AND created_datetime IS NOT NULL
        AND closed_datetime IS NOT NULL
        AND closed_datetime >= created_datetime
        AND resolution_hours IS NULL
        THEN 1 ELSE 0
    END) AS missing_eligible_resolutions,
    SUM(CASE
        WHEN resolution_hours < 0
        THEN 1 ELSE 0
    END) AS negative_resolutions
FROM service_requests_clean;

-- 0 invalid populated resolutions.
-- 0 missing eligible resolutions.
-- 0 negative resolution times.
-- Resolution-time cleaning logic validated.

--      f. final raw vs. cleaned dataset comparison
sELECT
    'Raw' AS dataset,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT unique_key) AS unique_requests
FROM service_requests
UNION ALL
SELECT
    'Cleaned' AS dataset,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT unique_key) AS unique_requests
FROM service_requests_clean;
-- Raw: 1,399,950 rows; 1,399,950 unique requests.
-- Cleaned: 1,399,950 rows; 1,399,950 unique requests.
-- All records preserved during cleaning.




-- ============================================================
-- FINAL CLEANING SUMMARY
-- ============================================================

-- All 1,399,950 records preserved with no duplicate IDs.
-- Date fields standardized and temporal features derived.
-- Status and borough formatting cleaned.
-- 6 complaint-type labels standardized; agency codes retained.
-- Resolution times calculated for eligible Closed requests.
-- Invalid, missing, and unresolved durations left NULL.
-- Extreme positive durations retained for further analysis.
-- Final validation checks passed.
-- Dataset ready for exploratory data analysis.