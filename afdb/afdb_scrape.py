################################################################################
# afdb/afdb-scrape.py                                                          #
#                                                                              #
# Copyright 2021 Evans Policy Analysis and Research Group (EPAR).              #
#                                                                              #
# This project is licensed under the 3-Clause BSD License. Please see the      #
# license.txt file for more information.                                       #
#                                                                              #
# This script crawls the African Development Bank project pages to             #
# create a database of specified information                                   #
################################################################################

__copyright__ = """
Copyright 2021 Evans Policy Analysis and Research Group (EPAR).
"""
__license__ = """
This project is licensed under the 3-Clause BSD License. Please see the 
license.txt file for more information.
"""

# Imports
import html
import pandas as pd
import requests
import sys
import time
from bs4 import BeautifulSoup

# Constants
DEBUG = False if len(sys.argv) == 1 else sys.argv[1] == "True"
BASE_URL = 'https://projectsportal.afdb.org/dataportal/VProject/show/'
CWD = './data/'
PROJECT_LIST_URL = 'https://projectsportal.afdb.org/dataportal/VProject/exportProjectList?reportName=dataPortal_project_list'
PROJECT_LIST = CWD + 'afdb_ids_debug.xlsx' if DEBUG else CWD + 'afdb_ids.xlsx'
OUTPUT_FILE = CWD + 'afdb_debug.csv' if DEBUG else CWD + 'afdb_data.csv'
try:
    DAC_LOOKUP = pd.read_excel('./DAC-CRS-CODES.xls', sheet_name='Purpose codes', header=2)
except Exception as e:
    print("Exception opening DAC code excel file: {0}".format(e))
    print("This error usually happens when running from the script from the wrong directory. Make sure to run from '411-IFI-Aid/'")

# Downloads the current list of AfDB projects
def download_afdb_projects_list():
    print('Downloading projects spreadsheet from the AfDB website')
    r = requests.get(PROJECT_LIST_URL)
    print('Download complete!')
    unfiltered_projs = open(PROJECT_LIST, 'wb')
    unfiltered_projs.write(r.content)
    unfiltered_projs.close()
    print('Writing unfiltered projects to ' + PROJECT_LIST)

# Download url and return a BeautifulSoup object from the resulting html
def get_html(url):
    attempts = 0
    # Retry up to 20 times, then quit
    while(attempts < 20):
        try:
            attempts += 1
            r = requests.get(url)
            clean_html = html.unescape(r.text)
            clean_html = "".join(line.strip() for line in clean_html.split("\n"))
            return BeautifulSoup(clean_html, 'html.parser')
        except (Exception) as e:
            print('Failed to download webpage, trying again')
            print(e)
            time.sleep(5)
    return None

# Find and return data from standard tables on the project page
def find_in_table(soup, var):
    try:
        temp = soup.body.find(text=var).parent.parent.find_next('td').contents[0]
        return temp
    except (Exception) as e:
        return ""

# Find and return data from nonstandard tables on the project page
def find_in_nonstandard_table(soup, var):
    try:
        temp = soup.body.find(text=var).find_parent(class_='col-md-4').find_next(class_='col-md-8').contents[0]
        return temp
    except (Exception) as e:
        return ""

# Find and return data from a project page's heading
def find_in_heading(soup, title):
    try: 
        temp = soup.body.find(text=title).parent.find_next('p').contents[0]
        return temp
    except (Exception) as e:
        return ""

# Returns the description of the given DAC code from the local DAC code spreadsheet
def get_dac5_desc(code):
    if code == None or len(code) < 3 or code == 'N/A':
        return "N/A"
    code = int(code)
    column_name = 'DAC 5 CODE' if code < 1000 else 'concatenate'
    desc = DAC_LOOKUP[DAC_LOOKUP[column_name] == code]['DESCRIPTION'].values[0]
    return desc

# Main
if not DEBUG:
    download_afdb_projects_list()

# Read in the unfiltered list of projects
df = pd.read_excel(PROJECT_LIST)
print('Filtering to active projects in IFI countries')
project_ids = df[df['Status'].isin(['Approved', 'Implementation'])]

scraped_data = []
# Scrape each project and store in scraped_data
for index, row in project_ids.iterrows():
    # Drop projects that are not approved or in progress
    if row['Project Code'] == None or row['Project Code'] == '' or (row['Status'] != 'Approved' and row['Status'] != 'Implementation'):
        next

    # Start timer
    start_time = time.time()
    
    print('\n\nScraping project: ' + row['Project Code'])
    data = {}
    soup = get_html(BASE_URL + row['Project Code'])

    # Get details from html
    data['Project ID'] = row['Project Code']
    data['Country'] = find_in_table(soup, 'Country').get_text()
    # Break down the "Country - Project Title" header to get the title
    cpt = soup.body.find('h2', class_='title').get_text().split('- ', 1)
    title = cpt[1] if len(cpt) == 2 else cpt[0]
    data['Project Title'] = title
    data['Status'] = find_in_table(soup, 'Status')
    data['Commitment in U.A.'] = find_in_table(soup, 'Commitment').split(' ', 1)[1]
    data['Source of Financing'] = find_in_nonstandard_table(soup, 'Funding').get_text()
    data['Sovereign'] = find_in_table(soup, 'Sovereign / Non-Sovereign').get_text()
    start_date = pd.to_datetime(find_in_table(soup, 'Approval Date'), infer_datetime_format=True)
    closing_date = pd.to_datetime(find_in_table(soup, 'Planned Completion Date'), infer_datetime_format=True)
    data['Project Duration'] = round((closing_date - start_date).days / 365.25, 2)
    data['Start Date'] = start_date.date().isoformat()
    data['Closing Date'] = closing_date.date().isoformat()
    data['Description'] = str(find_in_heading(soup, 'Project General Description')) 
    obj = str(find_in_heading(soup, 'Project Objectives'))
    data['Description'] += "\n" + obj if (obj != "" or obj == None) else ""
    data['Contact Name'] = str(find_in_table(soup, 'Name')).title()
    data['Contact Email'] = find_in_table(soup, 'Email')
    data['Sector'] = find_in_table(soup, 'Sector').get_text()
    data['DAC Sector Code'] = find_in_table(soup, 'DAC Sector Code')
    data['Detailed Description'] = get_dac5_desc(data['DAC Sector Code'])
    data['DAC5 Code'] = data['DAC Sector Code'][:3]
    data['DAC5 Description'] = get_dac5_desc(data['DAC5 Code'])
    
    [print(key,':',value) for key, value in data.items()]
    scraped_data.append(data)

    # Make sure to wait before scraping each page (10s delay requested by AfDB's robots.txt)
    elapsed = time.time() - start_time
    if elapsed < 10:
        print("Waiting %.2fs before next scrape" % (10 - elapsed))
        time.sleep(10 - elapsed)

# Convert into an excel file
print("Creating excel file '%s' with scraped data" % OUTPUT_FILE)
df = pd.DataFrame.from_records(scraped_data)

# Don't fail because the output file was open
while True:
    try:
        df.to_csv(open(OUTPUT_FILE, 'w'), index=False, line_terminator='\n', na_rep='NA')
        break
    except Exception as e:
        print("Failed to write to CSV file. Please make sure that 1) file is closed, and 2) you are running this script from the 411-IFI-Aid/ folder.")
        time.sleep(5)

print('All done!')