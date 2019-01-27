select location_name as country, a.cause_name, b.hierarchy_level, year, val
from 
	gbd_by_country a
	left join cause_hierarchy b on a.cause_name = b.cause_name
where measure_name = 'DALYs (Disability-Adjusted Life Years)'
  and metric_name = 'Rate'
  and year between 2008 and 2017
  and cause_outline not like 'C%'  