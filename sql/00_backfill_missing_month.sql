-- After data validation from stratified, random data sample, Feb 2020 was missing
-- After retrieving the data from the api, it needed to be inserted into the main database
-- this file is the steps taken to do that (with some personal data hidden)


-- attach new data
ATTACH DATABASE '.../NYC-311-Analysis/data/raw/nyc311_2020_02.sqlite'
AS feb_database;

-- verify data count is as expected (16,666)
SELECT COUNT(*)
FROM feb_database.service_requests;

-- verify status data (this was previous problem area when retrieving from the api)




-- check there are no dublicates between both databases
SELECT COUNT(*) AS duplicate_ids
FROM feb_database.service_requests f
JOIN main.service_requests m
    ON f.unique_key = m.unique_key;


-- insert new data
INSERT INTO main.service_requests
SELECT *
FROM feb_database.service_requests;

-- verify new data count is as ecpected (1,399,950)
SELECT COUNT(*)
FROM main.service_requests;

-- check subset is february and 16,666 rows
SELECT
    substr(created_date, 1, 7) AS year_month,
    COUNT(*) AS request_count
FROM main.service_requests
WHERE substr(created_date, 1, 7) = '2020-02'
GROUP BY year_month;


-- recheck duplicates
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT unique_key) AS unique_requests
FROM main.service_requests;

-- detach new database 
DETACH DATABASE feb_database;