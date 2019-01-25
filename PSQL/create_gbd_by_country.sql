drop table if exists gbd_by_country;

create table gbd_by_country 
 ( 
     measure_name	  text, 
     location_name	text, 
     sex_name		    text, 
     age_name		    text, 
     cause_name		  text, 
     metric_name	  text, 
     year			      integer, 
     val			      numeric, 
     upper			    numeric, 
     lower			    numeric 
 ); 