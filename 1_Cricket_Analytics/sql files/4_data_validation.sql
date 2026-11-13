use role sysadmin;
use warehouse compute_wh;
use schema cricket.clean;

-- Validate the data

-- 1. Match details
select * from cricket.clean.match_detail_clean
where match_type_number=4670;

-- 2. by batsman
select
    country, batter, sum(runs)
from delivery_clean_tbl
where match_type_number=4670
group by country,batter
order by 1,2,3 desc;

--3. by team
select country, sum(runs)+sum(extra_runs)
from delivery_clean_tbl
where match_type_number=4670
group by country
order by 1,2 desc;