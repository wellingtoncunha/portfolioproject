import psycopg2
import os
import unicodedata
import shutil
import zipfile

def load_file_to_postgres(connection_string, file_name, table_name, delimiter):
    connection = psycopg2.connect(connection_string)
    cursor = connection.cursor()
    source_file = open(file_name)
    copy_statement = """
        COPY """ + table_name + """ FROM STDIN WITH
            CSV
            HEADER
            DELIMITER AS '""" + delimiter + """'
            """
    cursor.copy_expert(sql = copy_statement, file = source_file)
    connection.commit()

def export_query_result(connection_string, file_name, query_file, delimiter):
    with open(query_file, 'r') as query_file:
        query_string = query_file.read()
    query_string = str(query_string)

    connection = psycopg2.connect(connection_string)
    cursor = connection.cursor()
    target_file = open(file_name, "w+")
    copy_statement = """
        COPY (""" + query_string + """) TO STDIN WITH
            CSV
            HEADER
            DELIMITER AS '""" + delimiter + """'
            """
    cursor.copy_expert(sql = copy_statement, file = target_file)

def create_temporary_folder(folder_name):
    if not os.path.exists(folder_name):
        os.makedirs(folder_name)

def remove_temporary_folder(folder_name):
    if os.path.exists(folder_name):
        shutil.rmtree(folder_name)

def execute_sql_scripts(connection_string, scripts_folder, script_prefix):
	folder = scripts_folder
	files = os.listdir(folder)  
	files.sort()
	for each in files:
		if each.find(script_prefix) > -1:
			print ("Executing " + each) 
			connection = psycopg2.connect(connection_string)
			cursor = connection.cursor()
			with open(os.path.join(folder, each), 'r') as query_file:
				query_string = query_file.read()
			query_string = str(query_string) #unicodedata.normalize('NFKD', str(query_string).decode('utf8')).encode('ascii','ignore')
			cursor.execute(query_string)
			connection.commit()		

def main():
    scripts_folder = "/Users/wellingtoncunha/Documents/projects/portfolioproject/psql"
    source_folder = "/Users/wellingtoncunha/Documents/projects/portfolioproject/Data"
    temporary_folder = "/Users/wellingtoncunha/tmp_gbd"
    connection_string = str("dbname=" + "portfolio" + \
                            " user=" + "portfolio" + \
                            " password=" + "portfolio" + \
                            " host=" + "localhost" + \
                            " port=" + "5432")

    create_temporary_folder(temporary_folder)

    #Executing table creation scripts
    execute_sql_scripts(connection_string, scripts_folder, "create")

    #Load cause hierarchy
    load_file_to_postgres(connection_string, os.path.join(source_folder, "gbd_cause_hierarchy.txt"), "public.cause_hierarchy", '\t')

    #Load gbd files
    files = os.listdir(source_folder)
    for file in files:
        if file.find("zip") > -1 and file.find("DATA") > -1:
            gbd_folder = os.path.join(temporary_folder, "gbd")
            
            zip_file = zipfile.ZipFile(os.path.join(source_folder ,file))
            zip_file.extractall(gbd_folder)
            zip_file.close()
 
            for each in os.listdir(gbd_folder):
                if each.find("csv") > -1:
                    load_file_to_postgres(connection_string, os.path.join(gbd_folder, each), "public.gbd_by_country", ',')
            remove_temporary_folder(gbd_folder)

    remove_temporary_folder(temporary_folder)

    export_query_result(
        connection_string=connection_string, 
        file_name=os.path.join(source_folder, "gbd_daly_rate_by_country_and_year.txt"), 
        query_file=os.path.join(scripts_folder, "export_gbd_to_sas.sql"), 
        delimiter='\t'
    )

    print("Complete without errors!")

if __name__ == "__main__":
    main()