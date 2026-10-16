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


-- 2.2 Identify the 5 most common complaint types by borough

with complaint_counts AS (
	select 
		borough,
		complaint_type_clean,
		count(*) as total_requests
	from service_requests_clean src 
	where borough is NOT NULL
	group by borough, complaint_type_clean 
),
ranked_complaints AS (
	select
		borough, 
		complaint_type_clean,
		total_requests,
		row_number() over (
			partition by borough
			order by total_requests DESC 
		) as complaint_rank
	from complaint_counts 
)
select 
	borough,
	complaint_rank,
	complaint_type_clean,
	total_requests
from ranked_complaints 
where complaint_rank <= 5
order by borough, complaint_rank;

-- Illegal Parking ranks #1 in Brooklyn, Queens, and Staten Island.
-- Noise - Residential ranks #1 in the Bronx and Manhattan.
-- HEAT/HOT WATER ranks #2 in the Bronx.
-- Manhattan's top 5 includes Encampment.
-- Borough patterns reflect sampled requests, not population-adjusted rates.


-- 2.3 Compare Illegal Parking proportions across boroughs

select 
	borough,
	count(*) as total_requests,
	sum( 
		case
			when complaint_type_clean like 'Illegal Parking'
			then 1
			else 0
		end
	)  as illegal_parking_requests,
	round(
		sum( 
			case
				when complaint_type_clean like 'Illegal Parking'
				then 1
				else 0
			end
		) * 100.0 / count(*),
		2
	) as pct_illegal_parking
from service_requests_clean src 
where borough is not null and borough not like 'unspecified'
group by borough
order by pct_illegal_parking desc;

-- Queens (16.37%) and Brooklyn (16.27%) had the highest
--   proportions of Illegal Parking requests in the sample.
-- Brooklyn had the highest count (68,418), but Queens
--   had a slightly higher percentage.
-- Manhattan had the lowest proportion (8.43%).
-- Percentages reflect sampled 311 requests, not actual
--   borough-wide complaint rates or parking prevalence.


-- 2.4 Compare top complaint patterns by season

with complaint_counts as (
	select
		created_season,
		complaint_type_clean,
		count(*) as total
	from service_requests_clean src 
	group by created_season, complaint_type_clean
),
ranked_complaints as (
	select
		created_season,
		complaint_type_clean,
		total,
		row_number() over (
			partition by created_season
			order BY total desc
		) as complaint_rank
	from complaint_counts
)
select 
	created_season,
	complaint_rank,
	complaint_type_clean,
	total
from ranked_complaints 
where complaint_rank <=5
order by created_season, complaint_rank;

/*
Findings:
- Illegal Parking ranked first in fall, spring, and summer.
- HEAT/HOT WATER ranked first in winter (52,227 requests).
- Noise - Street/Sidewalk ranked third in summer.
- Damaged Tree entered the top five only in summer.
- Seasonal rankings describe the sampled records and do not
- establish NYC-wide seasonal complaint volumes.
*/

-- 2.5 percent hot water by seasons 

select
	created_season,
	count(*) as total,
	sum(
		case 
			when complaint_type_clean = 'HEAT/HOT WATER'
			then 1
			else 0
		end
	) as heat_requests,
	round( 
		sum(
			case 
				when complaint_type_clean = 'HEAT/HOT WATER'
				then 1
				else 0
			end
		) * 100.0 / count(*),
		2
	) as pct_heat_requests
from service_requests_clean src 
group by created_season
order by pct_heat_requests desc;

/*
Findings:
- HEAT/HOT WATER accounted for 15.16% of winter requests,
  compared with 1.10% during summer.
- Fall (7.02%) and spring (5.65%) fell between these extremes.
- This indicates a strong seasonal pattern within the sample.
*/


-- 2.6 Compare Heat/Hot water proportions across boroughs
select 
	borough,
	count(*) as total_requests,
	sum( 
		case
			when complaint_type_clean = 'HEAT/HOT WATER'
			then 1
			else 0
		end
	)  as heat_requests,
	round(
		sum( 
			case
				when complaint_type_clean = 'HEAT/HOT WATER'
				then 1
				else 0
			end
		) * 100.0 / count(*),
		2
	) as pct_heat
from service_requests_clean src 
where borough is not null and borough <> 'unspecified'
group by borough
order by pct_heat desc;

/*
Findings:
- The Bronx had the highest proportion of HEAT/HOT WATER
  requests (12.10%), followed by Manhattan (8.07%).
- Staten Island had the lowest proportion (1.76%).
- Results describe complaint composition within the sample,
  not borough-wide rates of heating problems.
*/

-- 2.7 HEAT/HOT WATER by borough and season

select 
	borough,
	created_season,
	count(*) as total_requests,
	sum( 
		case
			when complaint_type_clean = 'HEAT/HOT WATER'
			then 1
			else 0
		end
	)  as heat_requests,
	round(
		sum( 
			case
				when complaint_type_clean = 'HEAT/HOT WATER'
				then 1
				else 0
			end
		) * 100.0 / count(*),
		2
	) as pct_heat
from service_requests_clean src 
where borough is not null and borough <> 'Unspecified'
group by borough, created_season
order by created_season, pct_heat desc;

/*
Findings:
- The Bronx had the highest proportion of HEAT/HOT WATER
  requests in every season.
- In winter, HEAT/HOT WATER accounted for 24.15% of sampled
  Bronx requests, compared with 17.11% in Manhattan and
  3.98% in Staten Island.
- All five boroughs had their highest HEAT/HOT WATER
  percentages in winter and lowest in summer.
- These percentages describe the sampled complaint mix,
  not population-adjusted rates of heating problems.
*/