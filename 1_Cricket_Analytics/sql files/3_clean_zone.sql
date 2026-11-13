use role sysadmin;
use warehouse compute_wh;
use schema cricket.clean;

-- step 1
-- extract elements from object data type

select
    meta['data_version']::text as data_version,
    meta['created']:: date as created,
    meta['revision']::number as revision
from
    cricket.raw.match_raw_tbl;

-- step 2: extract elements from info of varient datatype.
select  
info:match_type_number::text as match_type,
info:match_type::text as match_type,
info:season::text as season,
info:team_type::text as team_type,
info:overs::text as overs,
info:city::text as city,
info:venue::text as venue
from 
cricket.raw.match_raw_tbl;


--- Final query after all analysis (CTAS) -- Match details
create or replace transient table cricket.clean.match_detail_clean as
select
    info:match_type_number::int as match_type_number, 
    info:event.name::text as event_name,
    case
    when 
        info:event.match_number::text is not null then info:event.match_number::text
    when 
        info:event.stage::text is not null then info:event.stage::text
    else
        'NA'
    end as match_stage,   
    info:dates[0]::date as event_date,
    date_part('year',info:dates[0]::date) as event_year,
    date_part('month',info:dates[0]::date) as event_month,
    date_part('day',info:dates[0]::date) as event_day,
    info:match_type::text as match_type,
    info:season::text as season,
    info:team_type::text as team_type,
    info:overs::text as overs,
    info:city::text as city,
    info:venue::text as venue, 
    info:gender::text as gender,
    info:teams[0]::text as first_team,
    info:teams[1]::text as second_team,
    case 
        when info:outcome.winner is not null then 'Result Declared'
        when info:outcome.result = 'tie' then 'Tie'
        when info:outcome.result = 'no result' then 'No Result'
        else info:outcome.result
    end as matach_result,
    case 
        when info:outcome.winner is not null then info:outcome.winner
        else 'NA'
    end as winner,   

    info:toss.winner::text as toss_winner,
    initcap(info:toss.decision::text) as toss_decision, --initcap() -Converts the first letter of each word to uppercase and the remaining letters to lowercase
    --
    stg_file_name ,
    stg_file_row_number,
    stg_file_hashkey,
    stg_modified_ts
    from 
    cricket.raw.match_raw_tbl;





    --- PLAYERS data table
    -- Analysis
select
    raw.info:match_type_number::int as match_type_number,
    raw.info:players,
    raw.info:teams
from cricket.raw.match_raw_tbl as raw;

select
    raw.info:match_type_number::int as match_type_number,
    raw.info:players,
    raw.info:teams
from cricket.raw.match_raw_tbl as raw
where match_type_number=4670 ;

select 
    raw.info:match_type_number::int as match_type_number,
    p.*  --p.key::text as country
from cricket.raw.match_raw_tbl raw,
lateral flatten(input => raw.info:players)p
where match_type_number=4670;

select 
    raw.info:match_type_number::int as match_type_number,
  p.key::text as country
from cricket.raw.match_raw_tbl raw,
lateral flatten(input => raw.info:players)p
where match_type_number=4670;

select 
    raw.info:match_type_number::int as match_type_number,
  p.key::text as country,
  team.*
from cricket.raw.match_raw_tbl raw,
lateral flatten(input => raw.info:players)p,
lateral flatten(input=> p.value) team
where match_type_number=4670;

select 
    raw.info:match_type_number::int as match_type_number,
  p.key::text as country,
  team.value::text as players
from cricket.raw.match_raw_tbl raw,
lateral flatten(input => raw.info:players)p,
lateral flatten(input=> p.value) team
where match_type_number=4670;


-- Creating players table
drop table player_clean_tbl;
    create or replace table player_clean_tbl as 
select 
    rcm.info:match_type_number::int as match_type_number, 
    p.key::text as country,
    team.value:: text as player_name,
    stg_file_name ,
    stg_file_row_number,
    stg_file_hashkey,
    stg_modified_ts
from cricket.raw.match_raw_tbl rcm,
lateral flatten (input => rcm.info:players) p,
lateral flatten (input => p.value) team;

select * from player_clean_tbl;

desc table cricket.clean.player_clean_tbl;

-- Apply constraint on Players TABLE
alter table cricket.clean.player_clean_tbl
modify column match_type_number
set not null;

alter table cricket.clean.player_clean_tbl
modify column country
set not null;

alter table cricket.clean.player_clean_tbl
modify column player_name
set not null;

desc table cricket.clean.player_clean_tbl;

-- create primary key in match table
alter table cricket.clean.match_detail_clean
add constraint pk_match_type_number
primary key (match_type_number);

-- Establish foriegn key relationship between PLAYERS table and MATCH TABLE
alter table player_clean_tbl
add constraint fk_match_id
foreign key (match_type_number)
references cricket.clean.match_detail_clean(match_type_number);

desc table cricket.clean.player_clean_tbl;

select get_ddl('table','cricket.clean.player_clean_tbl');



--- DELIVERY DATA TABLE
create or replace transient table delivery_clean_tbl as
select s
    rcm.info:match_type_number::int as match_type_number, 
    i.value:team::text as country,
    o.value:over::int as over,
    d.value:bowler::text as bowler,
    d.value:batter::text as batter,
    d.value:non_striker::text as non_striker,
    d.value:runs.batter::text as runs,
    d.value:runs.extras::text as extras,
    d.value:runs.total::text as total,
    e.key::text as extra_type,
    e.value::number as extra_runs,
    w.value:player_out::text as player_out,
    w.value:kind::text as player_out_kind,
    w.value:fielders::variant as player_out_fielders,
    rcm.stg_file_name ,
    rcm.stg_file_row_number,
    rcm.stg_file_hashkey,
    rcm.stg_modified_ts
from cricket.raw.match_raw_tbl rcm,
lateral flatten (input => rcm.innings) i,
lateral flatten (input => i.value:overs) o,
lateral flatten (input => o.value:deliveries) d,
lateral flatten (input => d.value:extras,outer=>True) e,
lateral flatten (input => d.value:wickets, outer => True) w;

select distinct match_type_number from delivery_clean_tbl;

desc table cricket.clean.delivery_clean_tbl;

-- Apply Contraints to deliver_clean_table
alter table cricket.clean.delivery_clean_tbl
modify column match_type_number set not null;

alter table cricket.clean.delivery_clean_tbl
modify column team_name set not null;

alter table cricket.clean.delivery_clean_tbl
modify column over set not null;

alter table cricket.clean.delivery_clean_tbl
modify column bowler set not null;

alter table cricket.clean.delivery_clean_tbl
modify column batter set not null;

alter table cricket.clean.delivery_clean_tbl
modify column non_striker set not null;

-- fk relationship
alter table cricket.clean.delivery_clean_tbl
add constraint fk_delivery_match_id
foreign key (match_type_number)
references cricket.clean.match_detail_clean (match_type_number);

desc table cricket.clean.delivery_clean_tbl;

select get_ddl('table','cricket.clean.delivery_clean_tbl');