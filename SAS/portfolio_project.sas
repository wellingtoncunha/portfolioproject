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

*Select Level 3 of disease;
PROC SQL;
	CREATE TABLE GBD_LEVEL_3 AS
	SELECT *
	FROM GBD
	WHERE HIERARCHY_LEVEL = 3;
QUIT;

*Avg by country and disease and ranking disease by country partition;
PROC SQL;
	CREATE TABLE GBD_BY_CNTRY_AND_DISEASE_TMP_L3 AS
	SELECT 
		country,
		cause_name,
		avg(val) as avg_daly_rate
	FROM
		GBD_LEVEL_3
	group by country, cause_name
	order by country, avg_daly_rate desc, cause_name;
	
	CREATE TABLE GBD_BY_CNTRY_AND_DISEASE_L3 AS 		
	SELECT *, monotonic() as row_id
	FROM
		GBD_BY_CNTRY_AND_DISEASE_TMP_L3
	order by country, avg_daly_rate desc, cause_name;

	CREATE TABLE GBD_BY_CNTRY_AND_DISEASE_RANK_L3 AS
	SELECT 
		a.country,
		a.cause_name,
		a.avg_daly_rate,
		(select count(b.avg_daly_rate) 
		 from GBD_BY_CNTRY_AND_DISEASE_L3 b 
		 where a.country = b.country
		 and a.row_id >= b.row_id) as rank_by_country,
		a.row_id
	FROM
		GBD_BY_CNTRY_AND_DISEASE_L3 a;
	
	CREATE TABLE GBD_TOP10_BY_COUNTRY_L3 as
	select *
	from GBD_BY_CNTRY_AND_DISEASE_RANK_L3
	where rank_by_country <= 10
	order by country, rank_by_country;
QUIT;

PROC SORT DATA=GBD_TOP10_BY_COUNTRY_L3; BY country cause_name;

PROC SQL;
	CREATE TABLE GBD_DISEASE_ASSOCIATION AS
	SELECT
		a.row_id, a.country, a.cause_name as disease1, b.cause_name as disease2
	FROM
		GBD_TOP10_BY_COUNTRY_L3 a 
		join GBD_TOP10_BY_COUNTRY_L3 b on a.country = b.country
	WHERE a.cause_name <> b.cause_name
	  and a.cause_name < b.cause_name;

	create table GBD_DISEASE1 as 
	select disease1, count(1) as qtyoccurencesdisease1
	from
		GBD_DISEASE_ASSOCIATION
	group by disease1;
	
	create table GBD_ASSOCIATION_CANDIDATES as
	select a.disease1, a.disease2, count(country) as qtyoccurencesofboth, qtyoccurencesdisease1,
		(select count(distinct country) from GBD_DISEASE_ASSOCIATION) as qtycountries
	from
		GBD_DISEASE_ASSOCIATION as a
		join GBD_DISEASE1 as b on a.disease1 = b.disease1
	group by a.disease1, a.disease2, qtyoccurencesdisease1;
	
	select 
		CATX(' ', 'If disease', disease1, 'is present, then disease', disease2, 'is present') as Rule,
		qtyoccurencesofboth / qtycountries as support,
		qtyoccurencesofboth / qtyoccurencesdisease1 as confidence,
		qtyoccurencesofboth,
		qtyoccurencesdisease1,
		qtycountries
	from 
		GBD_ASSOCIATION_CANDIDATES (obs=20)
	order by 2 desc, 3 desc;
quit;


/*
proc sort data=GBD_TOP5_BY_COUNTRY;
	by cause_name;
RUN;

proc transpose data=GBD_TOP5_BY_COUNTRY out=GBD_BY_COUNTRY_AND_DISEASE_TRANSPOSED;
	by country notsorted;
	var avg_daly_rate;
	id cause_name;
run;

title 'Diseases';
proc distance data=GBD_TOP5_BY_COUNTRY_TRANSPOSED out=Dist method=gower;
	var interval(Alcohol_use_disorders--Stroke / std=Std);
	id Country;
run;

proc print data=Dist(Obs=10);
   title2 'First 10 observations in the output data set from PROC DISTANCE';
   run;
   
TITLE;
ODS GRAPHICS ON / ATTRPRIORITY=NONE;

proc distance data=GBD_TOP5_BY_COUNTRY nostd method=dgower out=TREE;
	id country;
	var nominal(cause_name) ratio(avg_daly_rate);
run;






PROC TREE DATA=TREE OUT=CLUS NCLUSTERS=3 NOPRINT;
ID country;
COPY avg_daly_rate cause_name;
RUN; QUIT;

PROC SORT DATA=CLUS; BY CLUSTER;

PROC PRINT DATA=CLUS NOOBS; BY CLUSTER;
VAR country avg_daly_rate ;
RUN; QUIT;



- Avg Val By Country and Disease
	- Sum top ? diseases to see the accumulated impact per country
	- Classify countries per number of years lost by top ? diseases
	
- Cluster by Country and Disease


Diseases that harms

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


/*
proc sort data=GBD_TOP5_BY_COUNTRY;
	by cause_name;
RUN;

proc transpose data=GBD_TOP5_BY_COUNTRY out=GBD_BY_COUNTRY_AND_DISEASE_TRANSPOSED;
	by country notsorted;
	var avg_daly_rate;
	id cause_name;
run;

title 'Diseases';
proc distance data=GBD_TOP5_BY_COUNTRY_TRANSPOSED out=Dist method=gower;
	var interval(Alcohol_use_disorders--Stroke / std=Std);
	id Country;
run;

proc print data=Dist(Obs=10);
   title2 'First 10 observations in the output data set from PROC DISTANCE';
   run;
   
TITLE;
ODS GRAPHICS ON / ATTRPRIORITY=NONE;

proc distance data=GBD_TOP5_BY_COUNTRY nostd method=dgower out=TREE;
	id country;
	var nominal(cause_name) ratio(avg_daly_rate);
run;






PROC TREE DATA=TREE OUT=CLUS NCLUSTERS=3 NOPRINT;
ID country;
COPY avg_daly_rate cause_name;
RUN; QUIT;

PROC SORT DATA=CLUS; BY CLUSTER;

PROC PRINT DATA=CLUS NOOBS; BY CLUSTER;
VAR country avg_daly_rate ;
RUN; QUIT;



- Avg Val By Country and Disease
	- Sum top ? diseases to see the accumulated impact per country
	- Classify countries per number of years lost by top ? diseases
	
- Cluster by Country and Disease


Diseases that harms

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