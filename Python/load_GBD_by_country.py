import psycopg2
import os
import unicodedata
import shutil
import patoolib
#from rarfile import RarFile
import rarfile
from rarfile import RarFile

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
#    cursor.copy_from(
#        file=source_file,
#        table=table_name,
#        sep='\t',
#        null='null'\
#        )
    connection.commit()
        
def load_gbd():
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
        if file.find("rar") > -1:
            gbd_folder = os.path.join(temporary_folder, "gbd")
            
            #RarFile.UNRAR_TOOL = "UnRAR Free.app"
            #with RarFile(os.path.join(source_folder, file)) as rf:
            #    rf.extractall()

            rarfile.UNRAR_TOOL = "/users/wellingtoncunha/Downloads/rar/unrar"
            #rarfile.RarFile(os.path.join(source_folder, file)).extractall(gbd_folder)
            opened_rar = rarfile.RarFile(os.path.join(source_folder, file))
            for f in opened_rar.infolist():
                print (f.filename, f.file_size)
            
            opened_rar.extractall()
            #RarFile(os.path.join(source_folder, file)).extract(path=gbd_folder)
            
            patoolib.extract_archive(os.path.join(source_folder, file), outdir=gbd_folder)
            for each in gbd_folder:
                if each.find("csv") > -1:
                    load_file_to_postgres(connection_string, os.path.join(gbd_folder, each), "public.gbd_by_country", ',')
            remove_temporary_folder(gbd_folder)

    remove_temporary_folder(temporary_folder)

if __name__ == "__main__":
    main()