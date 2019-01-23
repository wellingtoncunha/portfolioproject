import psycopg2
import os

connection_string = str("dbname=" + "portfolio" + \
                        " user=" + "portfolio" + \
                        " password=" + "portfolio" + \
                        " host=" + "localhost" + \
                        " port=" + "5432")

connection = psycopg2.connect(connection_string)
cursor = connection.cursor()
query_string = "drop table if exists gbd_by_country;"
cursor.execute(query_string)
connection.commit()

query_string = str( \
        "   create table gbd_by_country " + \
        "    ( " + \
        "        measure_name	text, " + \
        "        location_name	text, " + \
        "        sex_name		text, " + \
        "        age_name		text, " + \
        "        cause_name		text, " + \
        "        metric_name	text, " + \
        "        year			integer, " + \
        "        val			numeric, " + \
        "        upper			numeric, " + \
        "        lower			numeric " + \
        "    ); "
    )
cursor.execute(query_string)    
connection.commit()

base_folder = "/Users/wellingtoncunha/OneDrive/CSU/12 MIS480 Capstone - Business Analytics and Information Systems/Module 8 Trends, Future, and Roadmap for Business Intelligence Solutions/Data"
files = os.listdir(base_folder)
for file in files:
    if file.find("csv") > -1:
        source_file = open(os.path.join(base_folder, file))
        copy_statement = """
            COPY gbd_by_country FROM STDIN WITH
                CSV
                HEADER
                DELIMITER AS ','
            """
        cursor.copy_expert(sql = copy_statement, file = source_file)
        #cursor.copy_from(
        #        file=source_file,
        #        table="gbd",
        #        # columns=('name', 'country', 'source', 'type'),
        #        sep=',', #'\t',
        #        null='NULL'
        #    )
        connection.commit()
