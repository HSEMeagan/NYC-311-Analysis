-- NYC 311 Service Requests Analysis
-- Data validation


-- 1. Confirm total row count.
select count(*) from my_table;
-- 1696023


-- 2. Inspect columns/data types.

PRAGMA table_info(my_table);
-- Every column is 'text', no numerics, 44 columns 


-- 3. Confirm date range.
select 
	MAX(created_date) as Latest_date,
	MIN(created_date) as earliest_date
FROM my_table mt;
-- 2020-01-15T17:29:09.000 & 2026-09-14T08:29:36.000
-- Jan 15, 2020 - Sep 14, 2026


-- 4. Check the distribution across years/months

-- 4a. Check distribution by year
SELECT
    substr(created_date, 1, 4) AS year,
    COUNT(*) AS request_count
FROM my_table
GROUP BY year
ORDER BY year;

-- 2020	199992
-- 2021	329979
-- 2022	366078
-- 2023	199992
-- 2024	199992
-- 2025	199992
-- 2026	199998

-- 4b. Check distribution by year and month
SELECT
    substr(created_date, 1, 7) AS year_month,
    COUNT(*) AS request_count
FROM my_table
GROUP BY year_month
ORDER BY year_month;

-- 2020-01	16666
-- 2020-02	16666
-- 2020-03	16666
-- ...
-- 2021-06	29998
-- 2021-07	33331
-- 2021-08	29998
-- 2021-09	29998
-- ... 
-- 2022-03	32767
-- 2022-04	29998
-- ...
-- 2026-03	22222
-- 2026-04	22222
-- 2026-05	22222
-- 2026-06	22222
-- 2026-07	22222
-- 2026-08	22222
-- 2026-09	22222


-- 5. Check duplicate unique_key values.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT unique_key) AS unique_requests
FROM my_table;
--total rows: 1696023, unique requests:	1659835



-- 6. Check missing values in the important fields.
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN created_date IS NULL OR created_date = '' THEN 1 ELSE 0 END) AS missing_created_date,
    SUM(CASE WHEN closed_date IS NULL OR closed_date = '' THEN 1 ELSE 0 END) AS missing_closed_date,
    SUM(CASE WHEN complaint_type IS NULL OR complaint_type = '' THEN 1 ELSE 0 END) AS missing_complaint_type,
    SUM(CASE WHEN borough IS NULL OR borough = '' THEN 1 ELSE 0 END) AS missing_borough,
    SUM(CASE WHEN status IS NULL OR status = '' THEN 1 ELSE 0 END) AS missing_status
FROM my_table;
-- total: 1696023, missing created date: 0, missing closed date: 28,870, missing complaint type: 312, missing borough: 81977, misssing status: 437,126

-- 7. Inspect statuses and closed_date.
-- 7a. Check request statuses
SELECT
    status,
    COUNT(*) AS request_count
FROM my_table
GROUP BY status
ORDER BY request_count DESC;

select count(distinct status) from my_table;
-- 20,110

-- incredibly messy data, addresses and cities bleeding into this column
-- snippet:
-- (blank)	437126
-- ADDRESS	117895
-- BROOKLYN	104760
-- BRONX	91453
-- NEW YORK	57209
-- Closed	36035
-- CARPENTER AVENUE	23665
-- STATEN ISLAND	16508
-- INTERSECTION	10749
-- BROADWAY	8755)
-- NOSTRAND AVENUE	2004
-- 6 AVENUE	2000
-- ELMHURST	1923
-- The Police Department responded to the complaint and with the information available observed no evidence of the violation at that time.	1825

-- 7b. Compare status with missing closed dates
SELECT
    status,
    COUNT(*) AS total_requests,
    SUM(
        CASE
            WHEN closed_date IS NULL
                OR closed_date = ''
            THEN 1
            ELSE 0
        END
    ) AS missing_closed_date
FROM my_table
GROUP BY status
ORDER BY total_requests DESC;
--ex: 
-- (blank)	437126	5016
-- ADDRESS	117895	2482
-- BROOKLYN	104760	1496
-- BRONX	91453	625
-- NEW YORK	57209	1337
-- Closed	36035	0
-- CARPENTER AVENUE	23665	4
-- STATEN ISLAND	16508	348
-- INTERSECTION	10749	289)

-- 8. Confirm the intended months/years are actually represented.
SELECT
    substr(created_date, 1, 4) AS year,
    substr(created_date, 6, 2) AS month,
    COUNT(*) AS request_count
FROM my_table
GROUP BY year, month
ORDER BY year, month;

-- not accurately represented 


-- 9. Investigate suspected column misalignment by year

SELECT
    substr(created_date, 1, 4) AS year,
    COUNT(*) AS total_rows,
    SUM(
        CASE
            WHEN status IN (
                'Closed',
                'Open',
                'Pending',
                'In Progress',
                'Assigned',
                'Started',
                'Unspecified',
                'Cancel'
            )
            THEN 1
            ELSE 0
        END
    ) AS recognized_status_rows
FROM my_table
GROUP BY year
ORDER BY year;

-- 10. Inspect rows with suspected shifted columns

SELECT *
FROM my_table
WHERE status IN (
    'ADDRESS',
    'BROOKLYN',
    'BRONX',
    'CARPENTER AVENUE',
    'INTERSECTION'
)
LIMIT 20;


/*
Validation identified inconsistent column alignment across portions
of the initial extracted dataset. The status field contained values
belonging to other fields, including address types, boroughs, street
names, and resolution descriptions.

Further investigation showed that records from different extraction
periods were not consistently aligned to the same schema when combined.

Because correcting shifted fields after import could introduce
additional data integrity issues, the dataset was re-extracted using
a consistent predefined schema rather than repaired manually.
*/