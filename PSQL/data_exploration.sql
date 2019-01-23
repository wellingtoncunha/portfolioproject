
select count(*) from gbd;

select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'gbd';
  
select * from gbd limit 10;

select min(year), max(year) from gbd_by_country;

select location_name as country, cause_name, year, val
from gbd_by_country
where measure_name = 'DALYs (Disability-Adjusted Life Years)'
  and metric = 'Rate'
  and year between 2008 and 2017;
  