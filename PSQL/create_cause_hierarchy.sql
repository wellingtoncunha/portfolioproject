drop table if exists cause_hierarchy;

create table cause_hierarchy 
(
  cause_id	      integer,
  cause_name	    text,
  parent_id	      integer,
  hierarchy_level integer,
  cause_outline	  text,
  sort_order	    numeric,
  yll_only	      text,
  yld_only	      text
);