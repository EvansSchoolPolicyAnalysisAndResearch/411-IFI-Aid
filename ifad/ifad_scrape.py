################################################################################
# ifad/ifad-scrape.py                                                          #
#                                                                              #
# Copyright 2021 Evans Policy Analysis and Research Group (EPAR).              #
#                                                                              #
# This project is licensed under the 3-Clause BSD License. Please see the      #
# license.txt file for more information.                                       #
#                                                                              #
# This script crawls the International Fund for Agricultural Development       #
# project pages to create a database of specified information                  #
################################################################################

__copyright__ = """
Copyright 2021 Evans Policy Analysis and Research Group (EPAR).
"""
__license__ = """
This project is licensed under the 3-Clause BSD License. Please see the 
license.txt file for more information.
"""

# Imports
import csv
import html
import pandas as pd
import re
import requests
import sys
import time
import unidecode
from bs4 import BeautifulSoup

# Constants
DEBUG = False if len(sys.argv) == 1 else sys.argv[1] == "-debug"
DEBUG_NUM_PROJECTS = 5
BASE_URL = 'https://www.ifad.org/en/web/operations/projects-and-programmes?mode=search'
TABS = [1,2,3]
PROJECT_URL = 'https://www.ifad.org/en/web/operations/-/project/'
OUTPUT_FILE = './data/ifad_data_debug.xlsx' if DEBUG else './data/ifad_data.xlsx'
IFI_COUNTRIES = {
    'Angola': 'Angola',
    'Benin': 'Benin',
    'Botswana': 'Botswana',
    'Burkina Faso': 'Burkina Faso',
    'Burundi': 'Burundi',
    'Cameroon': 'Cameroon',
    'Cabo Verde': 'Verde',
    'Central African Republic': 'Central African Republic',
    'Chad': 'Chad',
    'Comoros': 'Comoros',
    "Côte d'Ivoire": "Côte d'Ivoire",
    'Democratic Republic of the Congo': 'Democratic Republic of the Congo',
    'Equatorial Guinea': 'Equatorial Guinea',
    'Eritrea': 'Eritrea',
    'Eswatini': 'Eswatini',
    'Ethiopia': 'Ethiopia',
    'Gabon': 'Gabon',
    'Gambia': 'Gambia',
    'Gambia (The)': 'Gambia',
    'Ghana': 'Ghana',
    'Guinea': 'Guinea',
    'Guinea-Bissau': 'Guinea-Bissau',
    'Kenya': 'Kenya',
    'Lesotho': 'Lesotho',
    'Liberia': 'Liberia',
    'Madagascar': 'Madagascar',
    'Malawi': 'Malawi',
    'Mali': 'Mali',
    'Mauritania': 'Mauritania',
    'Mauritius': 'Mauritius',
    'Mozambique': 'Mozambique',
    'Namibia': 'Namibia',
    'Niger': 'Niger',
    'Nigeria': 'Nigeria',
    'Republic of Congo': 'Republic of the Congo',
    'Rwanda': 'Rwanda',
    'Sao Tome and Principe': 'Sao Tome and Principe',
    'Senegal': 'Senegal',
    'Seychelles': 'Seychelles',
    'Sierra Leone': 'Sierra Leone',
    'South Africa': 'South Africa',
    'South Sudan': 'South Sudan',
    'Tanzania': 'Tanzania',
    'United Republic of Tanzania': 'Tanzania',
    'Togo': 'Togo',
    'Uganda': 'Uganda',
    'Zambia': 'Zambia',
    'Zimbabwe' : 'Zimbabwe'
}

def get_html(url):
    attempts = 0
    while(attempts < 20):
        try:
            attempts += 1
            response = requests.get(url)
            clean_html = html.unescape(response.text)
            return BeautifulSoup(clean_html, 'html.parser')
        except (Exception) as e:
            print('Failed to download webpage, trying again')
            time.sleep(5)
    return None    

def get_proj_ids(url, tabs):
    """
    This function takes the BASE_URL and TABS to search
    and returns the list of project IDs to scrape
    """
    soup = get_html(url)
    projects = list()
    for i in tabs:
        # These are lists of HTML tags. use <element>.text to get to the actual text
        countries = soup.select('div.tab' + str(i) + ' div.project-info-container div.col-md-3')
        proj_ids = soup.select('div.tab' + str(i) + ' div.project-info-container div.col-md-2')
        del proj_ids[1::2] #project dates also match the col-md-2 filter; remove them by dropping every other match
        assert(len(proj_ids) == len(countries))
        # Merge IDs and countries into a single list of tuples
        id_and_country = tuple(zip(proj_ids, countries))
        # Filter projects for IFI countries "list(filter(lambda...))", then take only the project IDs from the resulting list (a_tuple[0].text)
        # Concepts: "filtering with lambdas" and "list comprehensions"
        relevant_ids = [a_tuple[0].text for a_tuple in (list(filter(lambda t : (t[1].text in IFI_COUNTRIES.keys()), id_and_country)))]
        projects.extend(relevant_ids)
    return projects

# Manual scraping method that finds param:to_find in param:soup and places its value in param:data
def manual_scrape(soup, data, to_find, column_name=None):
    try:
        ret = soup.find('dt', text=re.compile(r"\s*" + to_find + "\s*")).findNext().text.strip()
        data[column_name if column_name != None else to_find] = ret
        return ret
    except Exception as e:
        print(e)
        print('\t{0} not found'.format(to_find))

def rename_indicator(data, old_name, new_name):
    data[new_name] = data.pop(old_name)

# Main
projects = get_proj_ids(BASE_URL, TABS)
projects = projects if not DEBUG else projects[:DEBUG_NUM_PROJECTS]
scraped_data = []

for project_id in projects:
    data = {}
    url = PROJECT_URL + project_id
    print('Scraping {0}'.format(url))
    soup = get_html(url)
    if soup == None:
        next
    data['IFI'] = "International Fund for Agricultural Development"
    manual_scrape(soup, data, 'Country')
    data['Project ID'] = int(project_id)
    data['Project Title'] = soup.select("h1[class!=\"hide-accessible\"]")[0].text
    data['Status'] = soup.select('dd.project-status > span')[0].text[8:]
    manual_scrape(soup, data, 'Approval Date')
    manual_scrape(soup, data, 'Sector', 'Primary Sector')
    manual_scrape(soup, data, 'IFAD Financing', 'Commitment Amount (USD)')
        
    # Below line takes a number in the form "US$ 52.49 million" and translates it into "52490000"
    # Assumes that the project funding is in millions (which is not generally safe, but currently works)
    data['Commitment Amount (USD)'] = int(float(re.findall("[0-9]+\.*[0-9]*", data['Commitment Amount (USD)'])[0]) * 1000000)

    manual_scrape(soup, data, 'Duration', 'Project Duration')
    # Translates duration = "2021 - 2024" into "3"
    duration = re.split(' - ', data['Project Duration'])
    data['Project Duration'] = int(duration[1]) - int(duration[0])
    data['Closing Date'] = int(duration[1])

    #Scrape contact data
    contact_name = manual_scrape(soup, data, 'Project Contact')
    if contact_name != None and soup.find(text=contact_name) != None:
        data['Contact Details'] = soup.find(text=contact_name).parent['href'][7:]

    for key in data.keys():
        # Remove special characters, but not from country names
        if key != 'Country':
            data[key] = data[key] if type(data[key]) != str else unidecode.unidecode(data[key].strip()).strip()
        # Translate country names into IFI format
        else:
            data[key] = IFI_COUNTRIES[data[key]]

    # Print the scraped data
    [print('\t{0}: {1}'.format(key, value)) for key, value in data.items()] 
    print()
    
    #Add to list of projects
    scraped_data.append(data)

    ## Not currently used, but valid scrapes if needed
    # manual_scrape(soup, data, 'Total Project Cost')
    # manual_scrape(soup, data, 'Financing Gap')
    # manual_scrape(soup, data, 'Financing terms')
    # # Handle multiple international funders
    # int_funders = ''
    # f = soup.find(text='Co-financiers (International)')
    # while f != None and 'project-row-text' in f.findNext()['class']:
    #     int_funders += f.findNext().text.strip() + '); '
    #     f = f.findNext()
    # int_funders = int_funders[:-2].replace('US$', '(US$') # String cleanup
    
    # # Handle multiple domestic funders
    # dom_funders = ''
    # f = soup.find(text='Co-financiers (Domestic)')
    # while f != None and 'project-row-text' in f.findNext()['class']:
    #     dom_funders += f.findNext().text.strip() + '); '
    #     f = f.findNext()
    # dom_funders = dom_funders[:-2].replace('US$', '(US$') # String cleanup
    
    # # Add international and domestic funders to the lists
    # if len(int_funders) > 0:
    #     data['Co-financiers (International)'] = int_funders
    # if len(dom_funders) > 0:
    #     data['Co-financiers (Domestic)'] = dom_funders

# Export into excel file
print("Creating excel file '{0}' with scraped data".format(OUTPUT_FILE))
df = pd.DataFrame.from_records(scraped_data)

# Don't fail because the output file was open
while True:
    try:
        df.to_excel(OUTPUT_FILE, index=False, na_rep='', float_format='%.2f')
        break
    except Exception as e:
        print(e)
        print("Failed to write to Excel file. Please make sure that 1) file is closed, and 2) you are running this script from the 411-IFI-Aid/ folder.")
        time.sleep(5)

print('All done!')