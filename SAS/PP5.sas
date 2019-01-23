FILENAME REFFILE 
	'/folders/myfolders/sasuser.v94/SASDATA_ED2/daly_rate_by_country_and_year.txt';

PROC IMPORT DATAFILE=REFFILE
	DBMS=DLM
	OUT=gbd replace;
	DELIMITER="09"X;
	GETNAMES=YES;
RUN;