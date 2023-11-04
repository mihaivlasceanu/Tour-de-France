/*==================================
	IMPORTING THE DATASETS
====================================*/


CREATE TABLE tours (
year INT,
dates TEXT,
stages TEXT,
distance TEXT,
starters INT,
finishers INT
)

SELECT * FROM tours

-- \COPY tours FROM 'C:\Users\Public\tdf_tours.csv' WITH CSV HEADER DELIMITER ','


CREATE TABLE winners (
year INT,
country TEXT,
rider TEXT,
team TEXT,
time TEXT,
margin TEXT,
stages_won INT,
stages_led INT,
avg_speed TEXT,
height TEXT,
weight TEXT,
born DATE,
died DATE
)

SELECT * FROM winners

-- \COPY winners FROM 'C:\Users\Public\tdf_winners.csv' WITH CSV HEADER DELIMITER ','


CREATE TABLE stages (
year INT,
date DATE,
stage TEXT,
course TEXT,
distance TEXT,
type TEXT,
winner TEXT
)

SELECT * FROM stages

-- \COPY stages FROM 'C:\Users\Public\tdf_stages.csv' WITH CSV HEADER DELIMITER ',' ENCODING 'UTF8'


CREATE TABLE finishers (
year INT,
rank TEXT,
rider TEXT,
time TEXT,
team TEXT
)
 
SELECT * FROM finishers

-- \COPY finishers FROM 'C:\Users\Public\tdf_finishers.csv' WITH CSV HEADER DELIMITER ',' ENCODING 'UTF8'


/*===============================
	CLEANING THE TABLES
=================================*/

-- 1. TOURS table

SELECT * FROM tours


WITH tours_1 AS(
SELECT 
year,
TRIM(REPLACE(dates, RIGHT(dates,4),'')) as days,
stages,
SPLIT_PART(distance,' ',1) as distance_in_km,
starters, 
finishers
FROM tours 
)
	
, tours_2 AS (
SELECT
year,
days,
TRIM(REPLACE((REGEXP_REPLACE(days,'[–—]','-')),'202','2020')) as new_days,
stages,
TRIM(REPLACE(REPLACE(distance_in_km, RIGHT(distance_in_km,3),''),',',''))::numeric as distance_in_km,
starters, 
finishers,
ROUND(1.0*finishers/starters*100,1) as pct_finishers
FROM tours_1
)
	
, tours_3 AS (
SELECT
year,
new_days,
SPLIT_PART(new_days,'-', 1) as starting_date,
SPLIT_PART(new_days,'-', 2) as ending_date,
stages,
distance_in_km,
starters, 
finishers,
pct_finishers
FROM tours_2
)
	
, tours_4 AS (
SELECT
year, 
new_days,
SPLIT_PART(TRIM(starting_date),' ',1) as starting_day,
CASE WHEN SPLIT_PART(TRIM(starting_date),' ',2) = '' THEN SPLIT_PART(TRIM(ending_date),' ',2) END as starting_month,
SPLIT_PART(TRIM(ending_date),' ',1) as ending_day,
SPLIT_PART(TRIM(ending_date),' ',2) as ending_month,
stages,
distance_in_km,
starters, 
finishers,
pct_finishers
FROM tours_3
)
	
, tours_5 AS (
SELECT
year, 
new_days,
starting_day,
CASE WHEN starting_month IS NULL AND ending_month = 'July' THEN 'June'
WHEN starting_month IS NULL AND ending_month = 'August' THEN 'July'
WHEN starting_month IS NULL AND ending_month = 'September' THEN 'August'
ELSE starting_month END as starting_month,
ending_day,
ending_month,
stages,
distance_in_km,
starters, 
finishers,
pct_finishers
FROM tours_4
)
	
SELECT
year,
TO_DATE(starting_day||' '||starting_month||' '||year,'DD Month YYYY') as start_date,
TO_DATE(ending_day||' '||ending_month||' '||year, 'DD Month YYYY') as end_date,
stages,
distance_in_km,
starters, 
finishers,
pct_finishers
INTO tours_cleaned
FROM tours_5


SELECT * FROM tours_cleaned

-- 2. WINNERS table

SELECT * FROM winners


WITH winners_1 AS (
SELECT 
year,
country,
CASE WHEN rider='Tadej Poga?ar' THEN 'Tadej Pogačar' ELSE rider END AS rider,
team,
REPLACE(TRIM(SPLIT_PART(time,' ',1)),'h','') AS time_hours,
REGEXP_REPLACE(TRIM(SPLIT_PART(time,' ',2)),'[^\w\s]','') as time_minutes,
REGEXP_REPLACE(TRIM(SPLIT_PART(time,' ',3)),'[^\w\s]','')AS time_seconds,
margin,
CASE WHEN LENGTH(margin)=12 THEN '0'||TRIM(SPLIT_PART(margin,' ',2)) END as margin_hours,
CASE WHEN LENGTH(margin)=12 THEN TRIM(SPLIT_PART(margin,' ',3))
	 WHEN LENGTH(margin)=9 THEN TRIM(SPLIT_PART(margin,' ',2))
     WHEN LENGTH(margin)=8 THEN '0'||TRIM(SPLIT_PART(margin,' ',2)) END as margin_minutes,
CASE WHEN LENGTH(margin)=12 THEN TRIM(SPLIT_PART(margin,' ',4))
	 WHEN LENGTH(margin)=9 THEN TRIM(SPLIT_PART(margin,' ',3))
     WHEN LENGTH(margin)=8 THEN TRIM(SPLIT_PART(margin,' ',3))
	 WHEN LENGTH(margin)=5 THEN TRIM(SPLIT_PART(margin,' ',2)) 
     WHEN LENGTH(margin)=4 THEN '0'||TRIM(SPLIT_PART(margin,' ',2)) END as margin_seconds,
stages_won,
stages_led,
REPLACE(avg_speed,'km/h','') AS avg_speed_kmph,
REPLACE(height,'m','') AS height_metres,
REPLACE(weight,'kg','') AS weight_kg,
born,
died
FROM winners
)
	
, winners_2 AS (
SELECT
year,
country,
rider,
team,
NULLIF(time_hours,'')::int as time_hours,
NULLIF(time_minutes,'')::int as time_minutes,
NULLIF(time_seconds,'')::int as time_seconds,
NULLIF(REPLACE(margin_hours,'h',''),'')::int as margin_hours,
NULLIF(REGEXP_REPLACE(margin_minutes,'[^\w\s]','','g'),'')::int as margin_minutes,
NULLIF(REGEXP_REPLACE(margin_seconds,'[^\w\s]','','g'),'')::int as margin_seconds,
stages_won,
stages_led,
avg_speed_kmph::numeric,
REPLACE(height_metres,'.','')::int as height_cm,
weight_kg::int,
born,
died
FROM winners_1
)
	
, winners_3 AS (
SELECT 
year,
country,
rider,
team,
MAKE_INTERVAL(hours=>time_hours, mins=>time_minutes, secs=>time_seconds) as time_cleaned,
MAKE_INTERVAL(hours=>COALESCE(margin_hours,0), mins=>COALESCE(margin_minutes,0), secs=>COALESCE(margin_seconds,0)) as margin_cleaned,
stages_won,
stages_led,
avg_speed_kmph,
height_cm,
weight_kg,
born,
died
FROM winners_2
)
	
SELECT
year,
country,
rider,
team,
time_cleaned,
NULLIF(margin_cleaned,INTERVAL '00:00:00') as margin_cleaned,
time_cleaned-margin_cleaned as time_of_next_rider,
stages_won,
stages_led,
avg_speed_kmph,
height_cm,
weight_kg,
born,
died
INTO winners_cleaned
FROM winners_3


SELECT * FROM winners_cleaned
SELECT * FROM winners


-- 3. STAGES table

SELECT * FROM stages


WITH stages_1 AS (
SELECT
year,
date,
stage,
REGEXP_REPLACE(course,'West Germany', 'Germany','g') as course,
SPLIT_PART(distance,' ',1)::numeric as distance_in_km,
CASE WHEN type IN ('Flat','Flat stage','Flat Stage','Plain stage with cobblestones','Flat cobblestone stage','Plain stage','Half Stage') THEN 'Flat'
	 WHEN type IN ('Hilly stage','Hilly Stage','Intermediate stage','Transition stage') THEN 'Hilly'
	 WHEN type IN ('High mountain stage','Mountain Stage','Medium mountain stage[c]','Mountain Stage (s)','Medium-mountain stage','Mountain stage','Medium mountain stage','Stage with mountains','Stage with mountain(s)','Stage with mountain') THEN 'Mountain'
	 WHEN type IN ('Mountain time trial','Individual time trial') THEN 'Individual Time Trial' 
	 WHEN type = 'Team time trial' THEN 'Team Time Trial' END as type,
REGEXP_REPLACE(winner,'[\s]*\([A-Z]+\)','','g') as winner,
TRIM(BOTH '()' FROM ARRAY_TO_STRING(REGEXP_MATCHES(winner,'\([A-Z]+\)|$'),'')) as nationality
FROM stages
)

, stages_2 AS (
SELECT 
year,
date,
stage,
course,
distance_in_km,
type,
ARRAY_TO_STRING(REGEXP_MATCH(winner,'[\w]*[-–''\s.]*[\w]*[-–''\s.]*[\w]*[-–''\s.]*[\w]*'),'') as winner, -- solution to get rid of an extra character that TRIM would not solve (also, some last names had a '-')
nationality
FROM stages_1
)

SELECT
year,
date,
stage,
course,
distance_in_km,
type,
CASE WHEN winner = 'Cancelled and replaced by' THEN 'TI–Raleigh–Campagnolo' ELSE winner END as winner,
CASE WHEN winner = 'Switzerland' THEN 'SUI'
WHEN winner = 'Netherlands' THEN 'NED' 
WHEN winner = 'France' THEN 'FRA'
WHEN winner IN ('Belgium','Belgium A') THEN 'BEL'
ELSE nationality END as nationality
INTO stages_cleaned
FROM stages_2


SELECT * FROM stages_cleaned



-- splitting course column into "starting point", "starting_country", "ending_point", "ending_country":

WITH course_split AS (
SELECT 
year, 
date, 
stage, 
SPLIT_PART(course,' to ', 1) as starting_point,
SPLIT_PART(course,' to ', 2) as ending_point,
distance_in_km, 
type, 
winner, 
nationality
FROM stages_cleaned
)

, country_ident AS (
SELECT
year, 
date, 
stage, 
starting_point,
REGEXP_MATCH(starting_point,'\([\w]+\)|\([\w]+ [\w]+\)') as starting_country,
ending_point,
REGEXP_MATCH(ending_point,'\([\w]+\)|\([\w]+ [\w]+\)') as ending_country,
distance_in_km, 
type, 
winner, 
nationality
FROM course_split
)

, cleaned_countries AS (
SELECT
year, 
date, 
stage, 
starting_point,
TRIM(BOTH '()'FROM ARRAY_TO_STRING(starting_country,'')) as starting_country,
ending_point,
TRIM(BOTH '()' FROM ARRAY_TO_STRING(ending_country,'')) as ending_country,
distance_in_km, 
type, 
winner, 
nationality
FROM country_ident	
)

, fill_end_point AS (
SELECT
year, 
date, 
stage, 
starting_point,
starting_country,
CASE WHEN ending_point='' THEN starting_point ELSE ending_point END as ending_point,
ending_country,
distance_in_km, 
type, 
winner, 
nationality	
FROM cleaned_countries
)

, final_table AS (
SELECT
year, 
date, 
stage, 
REGEXP_REPLACE(starting_point,'\([\w]+\)|\([\w]+ [\w]+\)','') as starting_point,
CASE WHEN starting_country IS NULL THEN 'France' ELSE TRIM(BOTH '()' FROM ARRAY_TO_STRING(REGEXP_MATCH(starting_point,'\([\w]+\)|\([\w]+ [\w]+\)'),'')) END as starting_country,
REGEXP_REPLACE(ending_point,'\([\w]+\)|\([\w]+ [\w]+\)','') as ending_point,
CASE WHEN REGEXP_MATCH(ending_point,'\([\w]+\)|\([\w]+ [\w]+\)') IS NOT NULL THEN TRIM(BOTH '()' FROM ARRAY_TO_STRING(REGEXP_MATCH(ending_point,'\([\w]+\)|\([\w]+ [\w]+\)'),'')) ELSE 'France' END as ending_country,
distance_in_km, 
type, 
winner, 
nationality	
FROM fill_end_point
)

SELECT
*
INTO stages_cleaned_2
FROM final_table


SELECT * FROM stages_cleaned_2

-- \COPY stages_cleaned_2 TO 'C:\Users\Public\tdf_stages_2.csv' WITH CSV HEADER DELIMITER ',' ENCODING 'UTF8'
-- this new file (tdf_stages_2) we will enrich with location coordinates using Python, thus producing tdf_stages_3


CREATE TABLE stages_cleaned_3 (
year INT,
date DATE,
stage TEXT,
starting_point TEXT,
starting_country TEXT,
ending_point TEXT, 
ending_country TEXT,
distance_in_km NUMERIC,
type TEXT,
winner TEXT,
nationality TEXT,
full_starting_point TEXT,
starting_lat NUMERIC,
starting_long NUMERIC,
full_ending_point TEXT,
ending_lat NUMERIC,
ending_long NUMERIC	
)


-- \COPY stages_cleaned_3 FROM 'C:\Users\Public\tdf_stages_3.csv' WITH CSV HEADER DELIMITER ',' ENCODING 'UTF8'

SELECT * FROM stages_cleaned_3


-- 4. FINISHERS table

SELECT * FROM finishers


WITH finishers_1 AS (
SELECT
year,
rank::int,
REGEXP_REPLACE(rider, '\([a-zA-Z]+\)','') AS rider,
REGEXP_MATCH(rider,'\([a-zA-Z]+\)') AS nationality,
TRIM(REGEXP_REPLACE(time,'[^\d\s]','','g')) AS time,
team
FROM finishers 
WHERE rank<>'DSQ'  -- we have 34 fewer records with this condition
)
	
, finishers_2 AS (
SELECT
year,
rank,
REGEXP_REPLACE(rider,'\[[\d\w]+\]','') as rider,
TRIM(BOTH '()' FROM ARRAY_TO_STRING(nationality,'')) as nationality,
CASE WHEN LENGTH(time)=7 THEN '0'||time 
	 WHEN LENGTH(time)=5 THEN '00 '||time
	 WHEN LENGTH(time)=4 THEN '00 0'||time
	 WHEN LENGTH(time)=2 THEN '00 00 '||time
	 ELSE time END as time,
team
FROM finishers_1
)
	
, finishers_3 AS (
SELECT
year,
rank,
ARRAY_TO_STRING(REGEXP_MATCH(rider,'[\w]+ [\w-]+|[\w]+ [\w-]+ [\w]+'),'') as rider, --once again needed to remove the strange extra space at the end
nationality,
time,
NULLIF(SPLIT_PART(time,' ',1),'')::int AS time_hours,
NULLIF(SPLIT_PART(time,' ',2),'')::int AS time_minutes,
NULLIF(SPLIT_PART(time,' ',3),'')::int AS time_seconds,
team
FROM finishers_2
)
	
, finishers_4 AS (
SELECT
year,
rank,
rider,
nationality,
time,
MAKE_INTERVAL(hours=>time_hours, mins=>time_minutes, secs=>time_seconds) AS cleaned_time,
team
FROM finishers_3
)
	
SELECT
year,
rank,
rider,
nationality,
CASE WHEN rank='1' THEN cleaned_time
ELSE cleaned_time + FIRST_VALUE(cleaned_time) OVER (PARTITION BY year ORDER BY rank) END as cleaned_time,
team
INTO finishers_cleaned
FROM finishers_4
ORDER BY year, rank


SELECT * FROM finishers_cleaned



/*=====================================
	EXPLORATORY DATA ANALYSIS
=======================================*/


-- 1. Longest, shortest, average duration of tour:

WITH tour_durations AS (
SELECT
year,
start_date,
end_date,
DATE_PART('doy',end_date) - DATE_PART('doy',start_date) as duration_days,
distance_in_km
FROM tours_cleaned
)
	
SELECT
MIN(duration_days) as min_days,
MAX(duration_days) as max_days,
ROUND(AVG(duration_days)) as avg_days
FROM tour_durations

-- 2. Longest, shortest, average length of tour (distance):

SELECT
MIN(distance_in_km) as min_length,
MAX(distance_in_km) as max_length,
ROUND(AVG(distance_in_km)) as avg_length
FROM tours_cleaned

-- 3. Min, max, average number of pct_finishers:

SELECT
MIN(pct_finishers) as min_pct_finishers,
MAX(pct_finishers) as max_pct_finishers,
ROUND(AVG(pct_finishers)) as avg_pct_finishers
FROM tours_cleaned

-- 4. Top 10 years with most pct_finishers:

SELECT
year, 
pct_finishers
FROM tours_cleaned
ORDER BY 2 DESC
LIMIT 10

-- 5. Top 10 years with least finishers:

SELECT
year, 
pct_finishers
FROM tours_cleaned
ORDER BY 2 
LIMIT 10

-- 6.1. Total and average number of starters and finishers by decade (1903-2022):

SELECT
CASE WHEN year >= 1903 AND year <= 1912 THEN '1903-1912'
	 WHEN year >= 1913 AND year <= 1922 THEN '1913-1922'
	 WHEN year >= 1923 AND year <= 1932 THEN '1923-1932'
	 WHEN year >= 1933 AND year <= 1942 THEN '1933-1942'
	 WHEN year >= 1943 AND year <= 1952 THEN '1943-1952'
	 WHEN year >= 1953 AND year <= 1962 THEN '1953-1962'
	 WHEN year >= 1963 AND year <= 1972 THEN '1963-1972'
	 WHEN year >= 1973 AND year <= 1982 THEN '1973-1982'
	 WHEN year >= 1983 AND year <= 1992 THEN '1983-1992'
	 WHEN year >= 1993 AND year <= 2002 THEN '1993-2002'
	 WHEN year >= 2003 AND year <= 2012 THEN '2003-2012'
	 WHEN year >= 2013 AND year <= 2022 THEN '2013-2022' END as decade,
SUM(starters) as total_starters,
SUM(finishers) as total_finishers,
FLOOR(AVG(starters)) as avg_starters,
FLOOR(AVG(finishers)) as avg_finishers
FROM tours_cleaned
GROUP BY 1
ORDER BY CASE WHEN year >= 1903 AND year <= 1912 THEN '1903-1912'
			  WHEN year >= 1913 AND year <= 1922 THEN '1913-1922'
	 		  WHEN year >= 1923 AND year <= 1932 THEN '1923-1932'
	 		  WHEN year >= 1933 AND year <= 1942 THEN '1933-1942'
	 		  WHEN year >= 1943 AND year <= 1952 THEN '1943-1952'
	 		  WHEN year >= 1953 AND year <= 1962 THEN '1953-1962'
	 		  WHEN year >= 1963 AND year <= 1972 THEN '1963-1972'
	 		  WHEN year >= 1973 AND year <= 1982 THEN '1973-1982'
	 		  WHEN year >= 1983 AND year <= 1992 THEN '1983-1992'
	 		  WHEN year >= 1993 AND year <= 2002 THEN '1993-2002'
	 		  WHEN year >= 2003 AND year <= 2012 THEN '2003-2012'
	 		  WHEN year >= 2013 AND year <= 2022 THEN '2013-2022' END

-- 6.2. Same as above, but more efficient:

WITH decades_cte AS (
SELECT
CASE WHEN year >= 1903 AND year <= 1912 THEN '1903-1912'
	 WHEN year >= 1913 AND year <= 1922 THEN '1913-1922'
	 WHEN year >= 1923 AND year <= 1932 THEN '1923-1932'
	 WHEN year >= 1933 AND year <= 1942 THEN '1933-1942'
	 WHEN year >= 1943 AND year <= 1952 THEN '1943-1952'
	 WHEN year >= 1953 AND year <= 1962 THEN '1953-1962'
	 WHEN year >= 1963 AND year <= 1972 THEN '1963-1972'
	 WHEN year >= 1973 AND year <= 1982 THEN '1973-1982'
	 WHEN year >= 1983 AND year <= 1992 THEN '1983-1992'
	 WHEN year >= 1993 AND year <= 2002 THEN '1993-2002'
	 WHEN year >= 2003 AND year <= 2012 THEN '2003-2012'
	 WHEN year >= 2013 AND year <= 2022 THEN '2013-2022' END as decade,
SUM(starters) as total_starters,
SUM(finishers) as total_finishers,
FLOOR(AVG(starters)) as avg_starters,
FLOOR(AVG(finishers)) as avg_finishers
FROM tours_cleaned
GROUP BY 1)

SELECT
* 
FROM decades_cte
ORDER BY ARRAY_POSITION(ARRAY['1903-1912','1913-1922','1923-1932','1933-1942','1943-1952','1953-1962','1963-1972','1973-1982','1983-1992','1993-2002','2003-2012','2013-2022'], decade)

-- 7.1. Percent of finishers out of starters by decade:

WITH decades_cte AS (
SELECT
CASE WHEN year >= 1903 AND year <= 1912 THEN '1903-1912'
	 WHEN year >= 1913 AND year <= 1922 THEN '1913-1922'
	 WHEN year >= 1923 AND year <= 1932 THEN '1923-1932'
	 WHEN year >= 1933 AND year <= 1942 THEN '1933-1942'
	 WHEN year >= 1943 AND year <= 1952 THEN '1943-1952'
	 WHEN year >= 1953 AND year <= 1962 THEN '1953-1962'
	 WHEN year >= 1963 AND year <= 1972 THEN '1963-1972'
	 WHEN year >= 1973 AND year <= 1982 THEN '1973-1982'
	 WHEN year >= 1983 AND year <= 1992 THEN '1983-1992'
	 WHEN year >= 1993 AND year <= 2002 THEN '1993-2002'
	 WHEN year >= 2003 AND year <= 2012 THEN '2003-2012'
	 WHEN year >= 2013 AND year <= 2022 THEN '2013-2022' END as decade,
SUM(starters) as total_starters,
SUM(finishers) as total_finishers
FROM tours_cleaned
GROUP BY 1
)

SELECT 
decade,
ROUND(100.0*total_finishers/total_starters,2) as pct_finishers
FROM decades_cte
ORDER BY CASE WHEN decade = '1903-1912' THEN 0
			  WHEN decade = '1913-1922' THEN 1
	 		  WHEN decade = '1923-1932' THEN 2
	 		  WHEN decade = '1933-1942' THEN 3
	 		  WHEN decade = '1943-1952' THEN 4
	 		  WHEN decade = '1953-1962' THEN 5
	 		  WHEN decade = '1963-1972' THEN 6
	 		  WHEN decade = '1973-1982' THEN 7
	 		  WHEN decade = '1983-1992' THEN 8
	 		  WHEN decade = '1993-2002' THEN 9
	 		  WHEN decade = '2003-2012' THEN 10
	 		  WHEN decade = '2013-2022' THEN 11 END

-- 7.2. Same as above, but (once again) more efficient:

WITH decades_cte AS (
SELECT
CASE WHEN year >= 1903 AND year <= 1912 THEN '1903-1912'
	 WHEN year >= 1913 AND year <= 1922 THEN '1913-1922'
	 WHEN year >= 1923 AND year <= 1932 THEN '1923-1932'
	 WHEN year >= 1933 AND year <= 1942 THEN '1933-1942'
	 WHEN year >= 1943 AND year <= 1952 THEN '1943-1952'
	 WHEN year >= 1953 AND year <= 1962 THEN '1953-1962'
	 WHEN year >= 1963 AND year <= 1972 THEN '1963-1972'
	 WHEN year >= 1973 AND year <= 1982 THEN '1973-1982'
	 WHEN year >= 1983 AND year <= 1992 THEN '1983-1992'
	 WHEN year >= 1993 AND year <= 2002 THEN '1993-2002'
	 WHEN year >= 2003 AND year <= 2012 THEN '2003-2012'
	 WHEN year >= 2013 AND year <= 2022 THEN '2013-2022' END as decade,
SUM(starters) as total_starters,
SUM(finishers) as total_finishers
FROM tours_cleaned
GROUP BY 1
)

SELECT 
decade,
ROUND(100.0*total_finishers/total_starters,2) as pct_finishers
FROM decades_cte
ORDER BY ARRAY_POSITION(ARRAY['1903-1912','1913-1922','1923-1932','1933-1942','1943-1952','1953-1962','1963-1972','1973-1982','1983-1992','1993-2002','2003-2012','2013-2022'], decade)

-- 8. Most frequent tour winning country / no of wins by country:

SELECT
country,
COUNT(*) as tours_won
FROM winners_cleaned
GROUP BY 1
ORDER BY 2 DESC

-- 9. Most frequent stage winning country:

SELECT
nationality,
COUNT(*) as stages_won
FROM stages_cleaned_3
GROUP BY 1
ORDER BY 2 DESC

-- 10. Countries most frequently in top 10:

WITH top_finishers_cte AS (
SELECT
year, 
rank,
rider,
nationality
FROM finishers_cleaned
WHERE rank<=10
)

SELECT
nationality,
COUNT(*)
FROM top_finishers_cte
GROUP BY 1
ORDER BY 2 DESC

-- 11. Countries most frequently in top 5:

WITH top_finishers_cte AS (
SELECT
year, 
rank,
rider,
nationality
FROM finishers_cleaned
WHERE rank<=5
)

SELECT
nationality,
COUNT(*)
FROM top_finishers_cte
GROUP BY 1
ORDER BY 2 DESC

-- 12. Most frequent tour winner:

SELECT
rider,
COUNT(*) as tours_won
FROM winners_cleaned
GROUP BY 1
ORDER BY 2 DESC

-- 13. Most frequent stage winner:

SELECT
winner,
COUNT(*) as stages_won
FROM stages_cleaned_3
GROUP BY 1
ORDER BY 2 DESC

-- 14. Relationship between number of Tours won and number of stages won/led for (multiple Tour winners):

WITH tours_per_rider AS (
SELECT
rider,
COUNT(*) as tours_won
FROM winners_cleaned
GROUP BY 1
ORDER BY 2 DESC
)

SELECT
wc.year,
wc.rider,
tours_won,
stages_won,
stages_led
FROM winners_cleaned wc 
INNER JOIN tours_per_rider tpr ON wc.rider=tpr.rider
ORDER BY tours_won DESC, rider, year

-- 15. Riders most frequently in top 10 finishers:

WITH top_finishers_cte AS (
SELECT
year, 
rank,
rider,
nationality
FROM finishers_cleaned
WHERE rank<=10
)

SELECT
rider,
COUNT(*)
FROM top_finishers_cte
GROUP BY 1
ORDER BY 2 DESC

-- 16. Riders most frequently in top 5 finishers:

WITH top_finishers_cte AS (
SELECT
year, 
rank,
rider,
nationality
FROM finishers_cleaned
WHERE rank<=5
)

SELECT
rider,
COUNT(*)
FROM top_finishers_cte
GROUP BY 1
ORDER BY 2 DESC

-- 17. Min, max, average finish:

SELECT
MIN(time_cleaned),
MAX(time_cleaned),
AVG(time_cleaned)::interval(0)
FROM winners_cleaned

-- 18. Thinnest, widest, average margin:

SELECT
MIN(margin_cleaned),
MAX(margin_cleaned),
AVG(margin_cleaned)::interval(0)
FROM winners_cleaned

-- 19. Most competitive tours (thinnest margins):

SELECT
year,
margin_cleaned
FROM winners_cleaned
ORDER BY 2 
LIMIT 10

-- 20. Average height, weight, speed:

SELECT 
ROUND(AVG(avg_speed_kmph)) as avg_speed,
ROUND(AVG(height_cm)) as avg_height,
ROUND(AVG(weight_kg)) as avg_weight
FROM winners_cleaned

-- 21. BMI of winners:

SELECT
year, 
country, 
rider, 
ROUND(10000 * (weight_kg/(height_cm*height_cm)::numeric),2) as BMI
FROM winners_cleaned
ORDER BY year DESC
LIMIT 10

-- 22. Average BMI:

WITH bmi_cte AS (
SELECT
year, 
country, 
rider, 
ROUND(10000 * (weight_kg/(height_cm*height_cm)::numeric),2) as bmi
FROM winners_cleaned
)

SELECT
ROUND(AVG(bmi),2) as average_bmi
FROM 
bmi_cte

-- 23. Age at time of winning tour:

SELECT
tc.year, 
end_date,
rider,
born,
DATE_PART('years', AGE(end_date, born)) as age
FROM tours_cleaned tc
INNER JOIN winners_cleaned wc ON tc.year=wc.year

-- 24. Distribution of ages at time of winning Tour:

WITH winner_ages AS (
SELECT
tc.year, 
end_date,
rider,
born,
DATE_PART('years', AGE(end_date, born)) as age
FROM tours_cleaned tc
INNER JOIN winners_cleaned wc ON tc.year=wc.year
)

SELECT
age,
COUNT(*)
FROM winner_ages
GROUP BY 1
ORDER BY 2 DESC

SELECT * FROM winners_cleaned

-- 25. Min, max, average age at time of winning tour:

WITH winner_ages AS (
SELECT
tc.year, 
end_date,
rider,
born,
DATE_PART('years', AGE(end_date, born)) as age
FROM tours_cleaned tc
INNER JOIN winners_cleaned wc ON tc.year=wc.year
)

SELECT
MIN(age),
MAX(age),
FLOOR(AVG(age)) as avg
FROM winner_ages

-- 26. Correlation between age at time of winning Tour and distance of race/finishing time/margin/no of stages won or led/avg speed:

WITH winner_ages AS (
SELECT
tc.year, 
distance_in_km,
rider,
DATE_PART('years', AGE(end_date, born)) as age,
time_cleaned,
margin_cleaned,
stages_won,
stages_led,
avg_speed_kmph
FROM tours_cleaned tc
INNER JOIN winners_cleaned wc ON tc.year=wc.year
)

, repeat_winners AS (
SELECT
rider,
COUNT(*) as tours_won
FROM winners_cleaned
GROUP BY 1
HAVING COUNT(*)>1
ORDER BY 2 DESC
)

SELECT
wa.*,
tours_won
FROM winner_ages wa
INNER JOIN repeat_winners rw ON wa.rider=rw.rider
ORDER BY wa.rider, age

-- 27. Winner lifespans:

SELECT
year, 
rider,
born,
died,
DATE_PART('years', AGE(died, born)) as lifespan
FROM winners_cleaned 
WHERE died IS NOT NULL

-- 28. Top 10 finishers and finisher countries by year:

SELECT
year, 
rank,
rider,
nationality
FROM finishers_cleaned
WHERE rank<=10

-- 29. Fastest, slowest, average time by year:

SELECT
year, 
MIN(cleaned_time) as fastest_time,
MAX(cleaned_time) as slowest_time,
AVG(cleaned_time)::interval(0) as avg_time
FROM finishers_cleaned
WHERE cleaned_time IS NOT NULL
GROUP BY 1
ORDER BY 1

-- 30. Composition of tours by type:

SELECT
year,
type,
COUNT(*),
ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (PARTITION BY year),2) as pct
FROM stages_cleaned_3
GROUP BY 1,2
ORDER BY 1,2

-- 31. Composition of tours by type and distance:

SELECT
year,
type,
SUM(distance_in_km) as distance_of_type,
ROUND(100.0*SUM(distance_in_km)/SUM(SUM(distance_in_km)) OVER (PARTITION BY year),2) as pct
FROM stages_cleaned_3
GROUP BY 1,2
ORDER BY 1,2

-- 32. How many stages has each rider won, by year and type of stage:

SELECT
year, 
winner,
type,
COUNT(*)
FROM stages_cleaned_3
GROUP BY 1,2,3
ORDER BY 1,4 DESC,2

-- 33. Count of types of stages won by overall Tour winners:

CREATE EXTENSION unaccent  --needed to JOIN two tables irrespective of accents


WITH winner_stage_preferences AS (
SELECT
sc.year,
date,
stage,
full_starting_point,
full_ending_point,
distance_in_km,
type, 
winner as stage_winner,
nationality,
country,
rider as tour_winner,
time_Cleaned,
margin_cleaned,
stages_won,
stages_led,
avg_speed_kmph
FROM stages_cleaned_3 sc
INNER JOIN winners_cleaned wc ON  unaccent(sc.winner)=unaccent(wc.rider) AND sc.year=wc.year
)

SELECT
year, 
tour_winner,
type,
COUNT(*)
FROM winner_stage_preferences
GROUP BY 1,2,3
ORDER BY 1,2,4 DESC

-- 34. Importance of type of stages won in determining an overall Tour winner:
-- (aka what types of stages have Tour winners been historically good at / Tour winner profile)

WITH winner_stage_preferences AS (
SELECT
sc.year,
date,
stage,
full_starting_point,
full_ending_point
distance_in_km,
type, 
winner as stage_winner,
nationality,
country,
rider as tour_winner,
time_Cleaned,
margin_cleaned,
stages_won,
stages_led,
avg_speed_kmph
FROM stages_cleaned_3 sc
INNER JOIN winners_cleaned wc ON  unaccent(sc.winner)=unaccent(wc.rider) AND sc.year=wc.year
)

, winner_stage_preferences_2 AS (
SELECT
year, 
tour_winner,
type,
COUNT(*) as stage_count
FROM winner_stage_preferences
GROUP BY 1,2,3
)

SELECT
type,
SUM(stage_count) as type_count,
ROUND(100.0*SUM(stage_count)/SUM(SUM(stage_count)) OVER (), 2) as pct
FROM winner_stage_preferences_2 
GROUP BY 1
ORDER BY 2 DESC

-- 35. Years when the Tour winner didn't win a single stage:

SELECT 
year 
FROM winners_cleaned 
WHERE stages_won=0

-- 36. Percent of Tour winners without a single stage win:

SELECT
ROUND(100.0*(SELECT COUNT(*) FROM winners_cleaned WHERE stages_won=0)/COUNT(*),2)
FROM winners_cleaned

-- 37. Riders that won most types of stages:
-- (it seems no one has managed to win all 5 types of stages and only one rider has won 4)

WITH tour_stage_winners AS (
SELECT
sc.year,
date,
stage,
full_starting_point,
full_ending_point,
distance_in_km,
type, 
winner as stage_winner,
nationality,
country,
rider as tour_winner,
time_Cleaned,
margin_cleaned,
stages_won,
stages_led,
avg_speed_kmph
FROM stages_cleaned_3 sc
INNER JOIN winners_cleaned wc ON  unaccent(sc.winner)=unaccent(wc.rider) AND sc.year=wc.year
)

SELECT 
tour_winner,
COUNT(DISTINCT type)
FROM tour_stage_winners
GROUP BY 1
ORDER BY 2 DESC

-- 38. Time Gap Analysis, 
-- analyzing the time gaps between finishers to understand the competitiveness of the race throughout the years:
	
SELECT
year,
rank,
rider,
nationality,
cleaned_time as finish_time,
LAG(cleaned_time) OVER (PARTITION BY year ORDER BY rank) as previous_finish_time,
cleaned_time - FIRST_vALUE(cleaned_time) OVER (PARTITION BY year ORDER BY cleaned_time) as difference_from_winner,
cleaned_time - LAG(cleaned_time) OVER (PARTITION BY year ORDER BY rank) as difference_from_previous,
team 
FROM finishers_cleaned
WHERE cleaned_time IS NOT NULL

-- 39. Average time gaps through the years:

WITH time_gaps AS (
SELECT
year,
rank,
rider,
nationality,
cleaned_time as finish_time,
LAG(cleaned_time) OVER (PARTITION BY year ORDER BY rank) as previous_finish_time,
NULLIF(cleaned_time - FIRST_vALUE(cleaned_time) OVER (PARTITION BY year ORDER BY cleaned_time),'00:00:00') as difference_from_winner,
cleaned_time - LAG(cleaned_time) OVER (PARTITION BY year ORDER BY rank) as difference_from_previous,
team 
FROM finishers_cleaned
WHERE cleaned_time IS NOT NULL
)

SELECT 
year,
MIN(difference_from_winner) as min_difference_from_winner,
MAX(difference_from_winner) as max_difference_from_winner,
AVG(difference_from_winner)::interval(0) as avg_difference_from_winner,
MIN(difference_from_previous) as min_difference_from_previous,
MAX(difference_from_previous) as max_difference_from_previous,
AVG(difference_from_previous)::interval(0) as avg_difference_from_previous
FROM time_gaps
GROUP BY 1

-- 40. Top 10 most competitive races (compared to winner):

WITH time_gaps AS (
SELECT
year,
rank,
rider,
nationality,
cleaned_time as finish_time,
LAG(cleaned_time) OVER (PARTITION BY year ORDER BY rank) as previous_finish_time,
NULLIF(cleaned_time - FIRST_vALUE(cleaned_time) OVER (PARTITION BY year ORDER BY cleaned_time),'00:00:00') as difference_from_winner,
cleaned_time - LAG(cleaned_time) OVER (PARTITION BY year ORDER BY rank) as difference_from_previous,
team 
FROM finishers_cleaned
WHERE cleaned_time IS NOT NULL
)

, agg_time_gaps AS (
SELECT 
year,
MIN(difference_from_winner) as min_difference_from_winner,
MAX(difference_from_winner) as max_difference_from_winner,
AVG(difference_from_winner)::interval(0) as avg_difference_from_winner,
MIN(difference_from_previous) as min_difference_from_previous,
MAX(difference_from_previous) as max_difference_from_previous,
AVG(difference_from_previous)::interval(0) as avg_difference_from_previous
FROM time_gaps
GROUP BY 1
)

SELECT
year,
avg_difference_from_winner
FROM agg_time_gaps
ORDER BY 2 
LIMIT 10

-- 41. Top 10 most competitive races (overall, compared to previous):

WITH time_gaps AS (
SELECT
year,
rank,
rider,
nationality,
cleaned_time as finish_time,
LAG(cleaned_time) OVER (PARTITION BY year ORDER BY rank) as previous_finish_time,
NULLIF(cleaned_time - FIRST_vALUE(cleaned_time) OVER (PARTITION BY year ORDER BY cleaned_time),'00:00:00') as difference_from_winner,
cleaned_time - LAG(cleaned_time) OVER (PARTITION BY year ORDER BY rank) as difference_from_previous,
team 
FROM finishers_cleaned
WHERE cleaned_time IS NOT NULL
)

, agg_time_gaps AS (
SELECT 
year,
MIN(difference_from_winner) as min_difference_from_winner,
MAX(difference_from_winner) as max_difference_from_winner,
AVG(difference_from_winner)::interval(0) as avg_difference_from_winner,
MIN(difference_from_previous) as min_difference_from_previous,
MAX(difference_from_previous) as max_difference_from_previous,
AVG(difference_from_previous)::interval(0) as avg_difference_from_previous
FROM time_gaps
GROUP BY 1
)

SELECT
year,
avg_difference_from_previous
FROM agg_time_gaps
ORDER BY 2 
LIMIT 10

-- 42. Most successful teams at winning Tours:

SELECT 
DISTINCT team,
COUNT(*)
FROM winners_cleaned
GROUP BY 1
ORDER BY 2 DESC

-- 43. Most successful teams at winning stages:

SELECT
DISTINCT team,
COUNT(*)
FROM finishers_cleaned
GROUP BY 1
ORDER BY 2 DESC

-- 44. Tour winners' career evolutions:

(WITH top_finishers AS (
SELECT
rider,
year,
rank
FROM finishers_cleaned 
WHERE rank=1
)

SELECT
rider,
year,
rank
FROM finishers_cleaned
WHERE EXISTS (
	SELECT 1
	FROM top_finishers
	WHERE finishers_cleaned.rider=top_finishers.rider
) AND rank>1

UNION ALL

SELECT
rider,
year,
rank
FROM finishers_cleaned 
WHERE rank=1)
ORDER BY rider, year

-- 45. Nationality vs type of stage:

WITH country_vs_stage AS (
SELECT
year,
date, 
type, 
winner,
nationality
FROM stages_cleaned_3
WHERE nationality <> ''
)

SELECT
nationality,
type, 
COUNT(*)
FROM country_vs_stage
GROUP BY 1,2
ORDER BY 2, 3 DESC

-- 46. Individual vs team ranking, individual vs team time:

SELECT
year, 
rank,
rider,
nationality, 
cleaned_time, 
team, 
CASE WHEN team IS NOT NULL THEN FLOOR(AVG(rank) OVER (PARTITION BY team)) END as team_avg_rnk,
CASE WHEN cleaned_time IS NOT NULL AND team IS NOT NULL THEN (AVG(cleaned_time) OVER (PARTITION BY team))::interval(0) END as team_avg_time
FROM finishers_cleaned
ORDER BY 1,2

-- 47. Evolution of average rank:

WITH team_averages AS (
SELECT
year, 
rank,
rider,
nationality, 
cleaned_time, 
team, 
CASE WHEN team IS NOT NULL THEN FLOOR(AVG(rank) OVER (PARTITION BY team)) END as team_avg_rank,
CASE WHEN cleaned_time IS NOT NULL AND team IS NOT NULL THEN (AVG(cleaned_time) OVER (PARTITION BY team))::interval(0) END as team_avg_time
FROM finishers_cleaned
)

SELECT DISTINCT
year, 
team, 
team_avg_rank, 
team_avg_time
FROM team_averages
WHERE team IS NOT NULL
ORDER BY 1,3



-- exporting our final tables for use in Tableau:

--\COPY tours_cleaned TO 'C:\Users\Public\tdf_tours_cleaned.csv' WITH CSV HEADER DELIMITER ',' ENCODING 'UTF8'
--\COPY winners_cleaned TO 'C:\Users\Public\tdf_winners_cleaned.csv' WITH CSV HEADER DELIMITER ',' ENCODING 'UTF8'
--\COPY stages_cleaned_3 TO 'C:\Users\Public\tdf_stages_cleaned.csv' WITH CSV HEADER DELIMITER ',' ENCODING 'UTF8'
--\COPY finishers_cleaned TO 'C:\Users\Public\tdf_finishers_cleaned.csv' WITH CSV HEADER DELIMITER ',' ENCODING 'UTF8'


