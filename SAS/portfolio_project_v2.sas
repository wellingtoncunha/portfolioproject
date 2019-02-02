FILENAME REFFILE 
	'/folders/myfolders/sasuser.v94/SASDATA_ED2/gbd_daly_rate_by_country_and_year.txt';

PROC IMPORT DATAFILE=REFFILE
	DBMS=DLM
	OUT=gbd replace;
	DELIMITER="09"X;
	GETNAMES=YES;
	GUESSINGROWS=50000;
RUN;

*Select Level 3 of disease;
PROC SQL;
	CREATE TABLE GBD_LEVEL_2 AS
	SELECT *
	FROM GBD
	WHERE HIERARCHY_LEVEL = 2;
QUIT;

*Means by year;
PROC MEANS DATA=GBD_LEVEL_2;
	CLASS year;
	VAR val;
RUN;

*Avg by disease to detect the top 10 diseases that causes most harm Globally;
PROC SQL; * NOPRINT;
	CREATE TABLE GBD_BY_DISEASE AS
	SELECT 
		cause_name,
		avg(val) as avg_daly_rate
	FROM
		GBD_LEVEL_2
	GROUP BY cause_name
	ORDER BY 2 desc;
	
	select * 
	from GBD_BY_DISEASE (OBS=10)
	order by 2 desc;
QUIT;	

* Impact of disease per country;
PROC SQL;
	CREATE TABLE GBD_SUM_BY_COUNTRY_AND_YEAR AS
	SELECT 
		country,
		year,
		sum(val) as total_daly
	FROM	
		GBD_LEVEL_2
	GROUP BY country, year;
		
	CREATE TABLE GBD_AVERAGE_BY_COUNTRY AS
	SELECT
		country,
		avg(total_daly) as avg_daly
	FROM
		GBD_SUM_BY_COUNTRY_AND_YEAR
	GROUP BY COUNTRY
	order by 2 desc;
QUIT;

proc means data=GBD_AVERAGE_BY_COUNTRY StackODSOutput P5 P25 P75 P95 min max; 
var avg_daly;
*ods output summary=LongPctls;
run;

PROC SQL;
	CREATE TABLE GBD_COUNTRY_CLASSIFICATION AS
	SELECT country, avg_daly, life_quality_group
	FROM
	(
		SELECT
			country,
			avg_daly,
			CASE 
				WHEN avg_daly < 20000 THEN 'A - High Quality'
				WHEN avg_daly < 40000 THEN 'B - Good Quality'
				WHEN avg_daly < 60000 THEN 'C - Medium Quality'
				WHEN avg_daly < 80000 THEN 'D - Low Quality'
				ELSE 'E - Critical Quality'
			END AS life_quality_group
		FROM
			GBD_AVERAGE_BY_COUNTRY
	) as subselect;
	
	CREATE TABLE GBD_COUNTRY_CLASSIFICATION_RANK as 
	SELECT country, avg_daly, life_quality_group, 
		(select count(country) from GBD_COUNTRY_CLASSIFICATION as x where avg_daly <= y.avg_daly) as Rank
	FROM
		GBD_COUNTRY_CLASSIFICATION as y
	ORDER BY avg_daly;
QUIT;

proc sgplot data=GBD_COUNTRY_CLASSIFICATION;
	title height=14pt "Countries by Quality of Life Classification";
	hbar life_quality_group /;
	yaxis label="Life Quality Group";
	xaxis grid;	
run;

PROC SQL;
	SELECT country, avg_daly, life_quality_group, rank
	FROM 
		GBD_COUNTRY_CLASSIFICATION_RANK 
	WHERE rank in (
		select min(rank) from GBD_COUNTRY_CLASSIFICATION_RANK group by life_quality_group union all
		select min(rank) + 1 from GBD_COUNTRY_CLASSIFICATION_RANK group by life_quality_group union all
		select max(rank) from GBD_COUNTRY_CLASSIFICATION_RANK group by life_quality_group union all
		select max(rank) - 1 from GBD_COUNTRY_CLASSIFICATION_RANK group by life_quality_group
		
	)
	ORDER BY rank;
QUIT;

*Avg by country and disease and ranking disease by country partition;
PROC SQL;
	CREATE TABLE GBD_BY_COUNTRY_AND_DISEASE_TMP AS
	SELECT 
		country,
		cause_name,
		avg(val) as avg_daly_rate
	FROM
		GBD_LEVEL_2
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
	
	CREATE TABLE GBD_TOP5_BY_COUNTRY as
	select *
	from GBD_BY_COUNTRY_AND_DISEASE_RANK
	where rank_by_country <= 5
	order by country, rank_by_country;
QUIT;

ods graphics / reset width=7in height=8in imagemap;
proc sgplot data=GBD_TOP5_BY_COUNTRY;
	title height=14pt "Frequency of Top 5 Diseases that Most Impact Countries";
	title2 height=10pt "(number of times that a disease appears among top 5 for a country)";
	hbar cause_name / categoryorder=respdesc datalabel;
	yaxis label="Disease";
	xaxis grid;	
run;
ods graphics / reset;
title;

proc sort data=GBD_BY_COUNTRY_AND_DISEASE;
	by country cause_name;
RUN;

proc transpose data=GBD_BY_COUNTRY_AND_DISEASE out=GBD_TRANSPOSED;
	id cause_name;
	idlabel cause_name;
	var avg_daly_rate;
	by country;
run;

*PROC CLUSTER NOEIGEN METHOD=WARD RSQUARE NONORM OUT=TREE DATA=GBD_TRANSPOSED;
PROC CLUSTER METHOD=WARD RSQUARE OUT=TREE DATA=GBD_TRANSPOSED;
	ID country;
	VAR Cardiovascular_diseases--Substance_use_disorders;
RUN; QUIT;

PROC TREE DATA=TREE OUT=CLUS NCLUSTERS=10 NOPRINT;
ID country;
*COPY avg_daly_rate cause_name;
RUN; QUIT;

PROC SORT DATA=CLUS; BY CLUSTER;

/* Try to convert to one row with the cluter as first column and all countries separated by commas on second column;
PROC PRINT DATA=CLUS NOOBS; BY CLUSTER;
VAR country ;
RUN; QUIT;

proc sort data=CLUS;
	by cluster country;
RUN;
*/

data clusters;
	length countries $1000.;
	do until (last.cluster);
		set CLUS;
		by cluster notsorted;
		countries=catx(', ',countries,country);
   end;
   drop country;
run;

proc sql;
	select cluster, clusname, countries
	from
		clusters;
quit;

