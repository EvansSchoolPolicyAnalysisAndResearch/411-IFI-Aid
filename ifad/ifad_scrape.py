################################################################################
# ifad/ifad-scrape.py                                                          #
#                                                                              #
# Copyright 2021 Evans Policy Analysis and Research Group (EPAR).              #
#                                                                              #
# This project is licensed under the 3-Clause BSD License. Please see the      #
# license.txt file for more information.                                       #
#                                                                              #
# this script crawls the International Fund for Agricultural Development       #
# project pages to create a database of specified information                  #
#                                                                              #
#                                                                              #
# inputs: none                                                                 #
# outputs: a csv file containing project numbers, description, planned         #
#          completion date,  etc                                               #
################################################################################
import csv
import html
import logging
import pandas as pd
import re
import requests
import sys
import time
import unidecode
from bs4 import BeautifulSoup

DEBUG = False
BASE_URL = 'https://www.ifad.org/en/web/operations/projects-and-programmes?mode=search'
TABS = [1,2,3]
PROJECT_URL = 'https://www.ifad.int/en/web/operations/-/project/'
OUTPUT_FILE = './data/ifad_out_test.csv' if DEBUG else './data/ifad_out.csv'
IFI_COUNTRIES = ['Angola', 'Benin', 'Botswana', 'Burkina Faso', 'Burundi', 'Cameroon',
'Cabo Verde','Central African Republic','Chad','Comoros',"Côte d'Ivoire",'Democratic Republic of the Congo',
'Equatorial Guinea','Eritrea','Eswatini','Ethiopia','Gabon','Gambia','Gambia (The)', 'Ghana','Guinea',
'Guinea-Bissau','Kenya','Lesotho','Liberia','Madagascar','Malawi','Mali','Mauritania',
'Mauritius','Mozambique','Namibia','Niger','Nigeria','Republic of Congo','Rwanda',
'Sao Tome and Principe','Senegal','Seychelles','Sierra Leone','South Africa','South Sudan',
'Tanzania', 'United Republic of Tanzania', 'Togo','Uganda','Zambia','Zimbabwe']

def get_html(url):
    attempts = 0
    while(attempts < 20):
        try:
            attempts += 1
            response = requests.get(url)
            clean_html = html.unescape(response.text)
            return BeautifulSoup(clean_html, 'html.parser')
        except (Exception) as e:
            logging.info('Failed to download webpage, trying again')
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
        #These are lists of HTML tags. use <element>.text to get to the actual text
        countries = soup.select('div.tab' + str(i) + ' div.project-info-container div.col-md-3')
        proj_ids = soup.select('div.tab' + str(i) + ' div.project-info-container div.col-md-2')
        del proj_ids[1::2] #project dates also match the col-md-2 filter; remove them by dropping every other match
        assert(len(proj_ids) == len(countries))
        #Merge IDs and countries into a single list of tuples
        id_and_country = tuple(zip(proj_ids, countries))
        #Filter projects for IFI countries "list(filter(lambda...))", then take only the project IDs from the resulting list (a_tuple[0].text)
        #Concepts: "filtering with lambdas" and "list comprehensions"
        relevant_ids = [a_tuple[0].text for a_tuple in (list(filter(lambda t : (t[1].text in IFI_COUNTRIES), id_and_country)))]
        projects.extend(relevant_ids)
    return projects

#Manual scraping method that finds param:to_find in param:soup and places its value in param:data
def manual_scrape(soup, data, to_find):
    try:
        ret = soup.find('dt', text=re.compile(r"\s*" + to_find + "\s*")).findNext().text.strip()
        data[to_find] = ret
        return ret
    except Exception as e:
        logging.debug(e)
        logging.info('\t%s not found', to_find)

#MAIN
logging.basicConfig(stream=sys.stderr, level=logging.INFO)
projects = get_proj_ids(BASE_URL, TABS) if not DEBUG else ['2000003362', '2000001936']
scraped_data = []

for project_id in projects:
    data = {}
    url = PROJECT_URL + project_id
    logging.info('Scraping %s', url)
    soup = get_html(url)
    if soup == None:
        next
    data['Project ID'] = project_id
    manual_scrape(soup, data, 'Country')
    data['Project Title'] = soup.select("h1[class!=\"hide-accessible\"]")[0].text
    manual_scrape(soup, data, 'Total Project Cost')
    data['Status'] = soup.select('dd.project-status > span')[0].text[8:]
    manual_scrape(soup, data, 'Approval Date')
    manual_scrape(soup, data, 'Duration')
    manual_scrape(soup, data, 'IFAD Financing')
    manual_scrape(soup, data, 'Financing Gap')

    #Handle multiple international funders
    int_funders = ''
    f = soup.find(text='Co-financiers (International)')
    while f != None and 'project-row-text' in f.findNext()['class']:
        int_funders += f.findNext().text.strip() + '); '
        f = f.findNext()
    int_funders = int_funders[:-2].replace('US$', '(US$') #String cleanup
    
    #Handle multiple domestic funders
    dom_funders = ''
    f = soup.find(text='Co-financiers (Domestic)')
    while f != None and 'project-row-text' in f.findNext()['class']:
        dom_funders += f.findNext().text.strip() + '); '
        f = f.findNext()
    dom_funders = dom_funders[:-2].replace('US$', '(US$') #String cleanup
    
    #Add international and domestic funders to the lists
    if len(int_funders) > 0:
        data['Co-financiers (International)'] = int_funders
    if len(dom_funders) > 0:
        data['Co-financiers (Domestic)'] = dom_funders

    manual_scrape(soup, data, 'Financing terms')
    manual_scrape(soup, data, 'Sector')
    contact_name = manual_scrape(soup, data, 'Project Contact')
    if contact_name != None and soup.find(text=contact_name) != None:
        data['Contact Email'] = soup.find(text=contact_name).parent['href'][7:]

    for key in data.keys():
        #Remove special characters, but not from country names!
        if key != 'Country':
            data[key] = unidecode.unidecode(data[key].strip()).strip() 
    
    [logging.info('\t%s: %s', key, value) for key, value in data.items()] #Print the scraped data
    scraped_data.append(data)

#Convert into an excel file
logging.info("Creating excel file '%s' with scraped data" % OUTPUT_FILE)
df = pd.DataFrame.from_records(scraped_data)

#Don't fail because the output file was open..
while True:
    try:
        df.to_csv(open(OUTPUT_FILE, 'w'), index=False, line_terminator='\n', na_rep='NA')
        break
    except Exception as e:
        logging.warn("Failed to write to CSV file. Please make sure that 1) file is closed, and 2) you are running this script from the 411-IFI-Aid/ folder.")
        time.sleep(5)

logging.info('All done!')