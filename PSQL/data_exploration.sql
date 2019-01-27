
select count(*) from gbd_by_country;

select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'gbd_by_country';

select * from gbd_by_country limit 10;

select min(year), max(year) from gbd_by_country;

select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'cause_hierarchy';

select hierarchy_level, count(*) from cause_hierarchy group by hierarchy_level order by 1;

select * from cause_hierarchy order by hierarchy_level ;

select location_name as country, a.cause_name, b.hierarchy_level, year, val
from 
	gbd_by_country a
	left join cause_hierarchy b on a.cause_name = b.cause_name
where measure_name = 'DALYs (Disability-Adjusted Life Years)'
  and metric_name = 'Rate'
  and year between 2008 and 2017  
  and cause_outline not like 'C%'  --removing injuries;
  