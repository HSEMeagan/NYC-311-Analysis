-- NYC 311 Service Requests Analysis
-- Data validation

-- Row count + schema
-- Date range
-- Year/month distribution — confirm the stratified sampling worked as intended
-- Duplicate unique_keys
-- Missing critical fields
-- Status values — this is our quickest test that the column-alignment problem is fixed
-- Status vs. closed_date
-- Spot-check full rows across several years — especially 2020, 2021/22, and 2023–26

-- at a glance: 
select * from service_requests
limit 5;


-- Row count + schema
select count(*) from service_requests;
	-- 1383284
PRAGMA table_info(service_requests);
	-- all 43 columns are strings


-- Date Range
select 
	MIN(created_date) AS earliest, 
	MAX(created_date) AS latest
from service_requests;
	-- earliest: 2020-01-28 12:51:00.000 (January 28, 2020 @ 12:51 PM)
	-- latest: 2026-09-19T18:00:24.000 (September 19, 2026 @ 6:00 PM)
	
-- Year/month distribution
select 
	substr(created_date, 1, 7) as year_month,
	count(*) as request_count
from service_requests
group by year_month 
order by year_month;

-- 16,666 from every single year/month but missing 2020-02

-- fetched and added missing month (a_insert_missing_data.sql)
-----------------------------------------------------------------


-- Duplicate unique_keys
select 
	count(distinct unique_key) as individual_entry,
	count(*) as total
from service_requests;
	-- 1399950	1399950


-- Missing critical fields
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN created_date IS NULL OR created_date = '' THEN 1 ELSE 0 END) AS missing_created_date,
    SUM(CASE WHEN closed_date IS NULL OR closed_date = '' THEN 1 ELSE 0 END) AS missing_closed_date,
    SUM(CASE WHEN complaint_type IS NULL OR complaint_type = '' THEN 1 ELSE 0 END) AS missing_complaint_type,
    SUM(CASE WHEN borough IS NULL OR borough = '' THEN 1 ELSE 0 END) AS missing_borough,
    SUM(CASE WHEN status IS NULL OR status = '' THEN 1 ELSE 0 END) AS missing_status
FROM service_requests;
-- Created date: 0, closed date: 28,179, complaint type: 0, borough: 2339, status: 0


-- Status values
select 
	status, 
	count(*) as number
from service_requests
group by status
order by number desc;

--Closed		1369614
--In Progress	19590
--Open			4983
--Pending		3890
--Assigned		1345
--Started		304
--Unspecified	224



-- Status vs. closed_date
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
FROM service_requests
GROUP BY status
ORDER BY total_requests DESC;

--Closed		1369614	3067
--In Progress	19590	19402
--Open			4983	4022
--Pending		3890	899
--Assigned		1345	489
--Started		304		297
--Unspecified	224		3


SELECT
    substr(created_date, 1, 4) AS year,
    substr(created_date, 6, 2) AS month,
    COUNT(*) AS request_count
FROM service_requests
GROUP BY year, month
ORDER BY year, month;

-- every month has 16,666 from 01/2020 to 12/2025
-- the rest have 22,222 from 01/2026 to 09/2026(end) 


-- day distribution
SELECT
    CASE strftime('%w', created_date)
        WHEN '0' THEN 'Su'
        WHEN '1' THEN 'M'
        WHEN '2' THEN 'T'
        WHEN '3' THEN 'W'
        WHEN '4' THEN 'Th'
        WHEN '5' THEN 'F'
        WHEN '6' THEN 'Sa'
    END AS day_of_week,
    COUNT(*) AS request_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM service_requests), 2) AS percent_of_requests
FROM service_requests
GROUP BY strftime('%w', created_date)
ORDER BY strftime('%w', created_date);

--Su	154444	11.03
--M		172022	12.29
--T		242123	17.3
--W		176375	12.6
--Th	206089	14.72
--F		240697	17.19
--Sa	208200	14.87


-- time distrivution
SELECT
    CAST(strftime('%H', created_date) AS INTEGER) AS hour_of_day,
    COUNT(*) AS request_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM service_requests), 2) AS percent_of_requests
FROM service_requests
GROUP BY hour_of_day
ORDER BY hour_of_day;

--0		53103	3.79
--1		35465	2.53
--2		22896	1.64
--3		16876	1.21
--4		15104	1.08
--5		17266	1.23
--6		27544	1.97
--7		47178	3.37
--8		70209	5.02
--9		82500	5.89
--10	81659	5.83
--11	79710	5.69
--12	76211	5.44
--13	74979	5.36
--14	77610	5.54
--15	73209	5.23
--16	70455	5.03
--17	67846	4.85
--18	66063	4.72
--19	65152	4.65
--20	65034	4.65
--21	70891	5.06
--22	75736	5.41
--23	67254	4.8

-- day of month
SELECT
    CAST(strftime('%d', created_date) AS INTEGER) AS day_of_month,
    COUNT(*) AS request_count,
    ROUND(count(*) * 100.0 / (select count(*) from service_requests), 2) as percent
FROM service_requests
GROUP BY day_of_month
ORDER BY day_of_month;

--1		21031	1.5
--2		76192	5.44
--3		69125	4.94
--4		74303	5.31
--5		68063	4.86
--6		54753	3.91
--7		48714	3.48
--8		60856	4.35
--9		77919	5.57
--10	71801	5.13
--11	81758	5.84
--12	94702	6.76
--13	82173	5.87
--14	64358	4.6
--15	45744	3.27
--16	55853	3.99
--17	72652	5.19
--18	66952	4.78
--19	46774	3.34
--20	30153	2.15
--21	25632	1.83
--22	28296	2.02
--23	13775	0.98
--24	1707	0.12
--25	8907	0.64
--26	20964	1.5
--27	13112	0.94
--28	10556	0.75
--29	6453	0.46
--30	6672	0.48
