FILENAME REFFILE 
	'/folders/myfolders/sasuser.v94/SASDATA_ED2/gbd_daly_rate_by_country_and_year.txt';

PROC IMPORT DATAFILE=REFFILE
	DBMS=DLM
	OUT=gbd replace;
	DELIMITER="09"X;
	GETNAMES=YES;
RUN;

*Means by year;
PROC MEANS DATA=gbd;
	CLASS year;
	VAR val;
	*OUTPUT OUT = WORK.CARS_MSRP_TMP;
RUN;

*Avg by disease to detect the top 10 diseases that causes most harm in Globally;
PROC SQL; * NOPRINT;
	CREATE TABLE GBD_BY_DISEASE AS
	SELECT 
		cause_name,
		avg(val) as avg_daly_rate
	FROM
		GBD
	GROUP BY cause_name
	ORDER BY 2 desc;
	
	select * 
	from GBD_BY_DISEASE (OBS=10)
	order by 2 desc;
QUIT;	

*Avg by country and disease and ranking disease by country partition;
PROC SQL;
	CREATE TABLE GBD_BY_COUNTRY_AND_DISEASE_TMP AS
	SELECT 
		country,
		cause_name,
		avg(val) as avg_daly_rate
	FROM
		gbd
	group by country, cause_name
	order by country, avg_daly_rate desc, cause_name;
	
	CREATE TABLE GBD_BY_COUNTRY_AND_DISEASE AS 		
	SELECT *, monotonic() as row_id
	FROM
		GBD_BY_COUNTRY_AND_DISEASE_TMP
	order by country, avg_daly_rate desc, cause_name;

	CREATE TABLE GBD_BY_COUNTRY_AND_DISEASE_RANK AS
	SELECT 
		a.country,
		a.cause_name,
		a.avg_daly_rate,
		(select count(b.avg_daly_rate) 
		 from GBD_BY_COUNTRY_AND_DISEASE b 
		 where a.country = b.country
		 and a.row_id >= b.row_id) as rank_by_country 
	FROM
		GBD_BY_COUNTRY_AND_DISEASE a;
	
	select *
	from GBD_BY_COUNTRY_AND_DISEASE_RANK
	where country = 'Albania'
	order by avg_daly_rate, cause_name desc;
QUIT;
/*

- Avg Val By Country and Disease
	- Sum top ? diseases to see the accumulated impact per country
	- Classify countries per number of years lost by top ? diseases
	
- Cluster by Country and Disease


Diseases that harms
*/

/*
Code vault (not used in final project)
FILENAME REFFILE 
	'/folders/myfolders/sasuser.v94/SASDATA_ED2/gbd_cause_hierarchy.txt';

PROC IMPORT DATAFILE=REFFILE
	DBMS=DLM
	OUT=cause replace;
	DELIMITER="09"X;
	GETNAMES=YES;
RUN;

*Joining cause hiearachy to roll up to level 3;
PROC SQL;
	SELECT 
		*
	FROM
		daly a
		LEFT JOIN cause b on a.cause_name = b.cause_name;
QUIT;


*/