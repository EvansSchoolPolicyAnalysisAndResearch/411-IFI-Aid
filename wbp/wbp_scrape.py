################################################################################
# wbp/wbp-scrape.py                                                            #
#                                                                              #
# Copyright 2021 Evans Policy Analysis and Research Group (EPAR).              #
#                                                                              #
# This project is licensed under the 3-Clause BSD License. Please see the      #
# license.txt file for more information.                                       #
#                                                                              #
# This script downloads information from the World Bank Projects API           #
# to create a database of specified information                                #
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
import json
import pandas as pd
import requests
import sys
import time
from bs4 import BeautifulSoup

# Constants
DEBUG = False if len(sys.argv) == 1 else sys.argv[1] == "-debug"
DEBUG_NUM_PROJECTS = 5
PROJECT_LIST_URL = 'https://search.worldbank.org/api/projects/all.xls'
CWD = "./data/"
PROJECT_LIST = CWD + 'wbp_unfiltered.xls'
FILTERED_PROJECT_LIST = CWD +'wbp_data_debug.xlsx' if DEBUG else CWD + 'wbp_data.xlsx'
PROJECT_API = "http://search.worldbank.org/api/v2/projects?format=json&fl=id,teamleadname&id="
DROP_COLUMNS = ['Region', 'Consultant Services Required', 'IBRD Commitment ', 'IDA Commitment', 'Grant Amount',
    'Environmental Assessment Category','Environmental and Social Risk', 'Total IDA and IBRD Commitment', 'Implementing Agency', 'Financing Type',
    'Borrower', 'Lending Instrument','Current Project Cost', 'Project URL']
RENAME_COLUMNS = {'Project Name': 'Project Title', 'Project Status':'Status', 'Project Development Objective ':'Description', 
    'Project Closing Date':'Closing Date', 'Board Approval Date': 'Approval Date', 'Sector 1' : 'Primary Sector'}

# Key = WB country name format, Value = IFI project country name format
IFI_COUNTRIES = { 
    'Republic of Angola': 'Angola',
    'Republic of Benin' : 'Benin',
    'Republic of Botswana' : 'Botswana',
    'Burkina Faso' : 'Burkina Faso',
    'Republic of Burundi' : 'Burundi',
    'Republic of Cameroon' : 'Cameroon',
    'Republic of Cabo Verde' : 'Cabo Verde',
    'Central African Republic' : 'Central African Republic',
    'Republic of Chad' : 'Chad',
    'Union of the Comoros' : 'Comoros',
    "Republic of Cote d'Ivoire" : "Côte d'Ivoire",
    'Democratic Republic of the Congo' : 'Democratic Republic of the Congo',
    'Republic of Equatorial Guinea' : 'Equatorial Guinea',
    'State of Eritrea' : 'Eritrea',
    'Kingdom of Eswatini' : 'Eswatini',
    'Federal Democratic Republic of Ethiopia' : 'Ethiopia',
    'Gabonese Republic' : 'Gabon',
    'Republic of The Gambia' : 'Gambia',
    'Republic of Ghana' :  'Ghana',
    'Republic of Guinea' : 'Guinea',
    'Republic of Guinea-Bissau' : 'Guinea-Bissau',
    'Republic of Kenya' : 'Kenya',
    'Kingdom of Lesotho' : 'Lesotho',
    'Republic of Liberia' : 'Liberia',
    'Republic of Madagascar' : 'Madagascar',
    'Republic of Malawi' : 'Malawi',
    'Republic of Mali' : 'Mali',
    'Islamic Republic of Mauritania' : 'Mauritania',
    'Republic of Mauritius' : 'Mauritius',
    'Republic of Mozambique' : 'Mozambique',
    'Republic of Namibia' : 'Namibia',
    'Republic of Niger' : 'Niger',
    'Federal Republic of Nigeria' : 'Nigeria',
    'Republic of Congo' : 'Republic of the Congo',
    'Republic of Rwanda' : 'Rwanda',
    'Democratic Republic of Sao Tome and Pricipe' : 'Sao Tome and Principe',
    'Republic of Senegal' : 'Senegal',
    'Republic of Seychelles' : 'Seychelles',
    'Republic of Sierra Leone' : 'Sierra Leone',
    'Republic of South Africa' : 'South Africa',
    'Republic of South Sudan' : 'South Sudan',
    'United Republic of Tanzania' : 'Tanzania',
    'Republic of Togo' : 'Togo',
    'Republic of Uganda' : 'Uganda',
    'Republic of Zambia' : 'Zambia',
    'Republic of Zimbabwe' : 'Zimbabwe',
    #Include regions
    'Eastern Africa' : 'Eastern Africa',
    'Western Africa' : 'Western Africa',
    'Central Africa' : 'Central Africa',
    'Southern Africa' : 'Southern Africa',
    'Multi-Region' : 'Multinational'
}
# Add Western Africa, Eastern African, Southern Africa, Central Africa
MULTI_REGION = ['World']

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

# Main
if not DEBUG:
    # Download the excel spreadsheet from the world bank website
    print("Downloading projects spreadsheet from the WB website")
    r = requests.get(PROJECT_LIST_URL)
    print("Download complete!")
    unfiltered_projs = open(PROJECT_LIST, 'wb')
    unfiltered_projs.write(r.content)
    unfiltered_projs.close()
    print("Writing unfiltered projects to " + PROJECT_LIST)

print("Filtering to active projects in IFI countries")
# Read in the unfiltered list of projects
df = pd.read_excel(PROJECT_LIST, header=1)

df['IFI'] = 'World Bank'
# Commitment amount = IDA + IBRD + grant amounts. (Do this before dropping the Total & Grant columns)
df['Commitment Amount (USD)'] = df['Total IDA and IBRD Commitment'] + df['Grant Amount']
#Drop unneeded indicators and rename others
df.drop(DROP_COLUMNS, axis=1, inplace=True)
df.rename(columns=RENAME_COLUMNS, inplace=True)
# Drop non-IFI countries
df = df[df['Country'].isin(list(IFI_COUNTRIES.keys()) + MULTI_REGION)]
# Standardize country names to IFI project format
df = df.replace(IFI_COUNTRIES)
# Drop inactive projects (possible states: Active*, Pipeline*, Dropped, Closed)
df = df[df['Status'].isin(['Active', 'Pipeline'])]

# Drop world and multi-regional projects without an IFI country name in the description
# Get multiregion projects
multiregion = df[((df['Country'] == 'World') | (df['Country'] == 'Multinational'))]
# Drop multiregion projects that don't have any IFI countries in the description
to_drop = multiregion[~multiregion['Description'].fillna(value="").str.contains('|'.join(list(IFI_COUNTRIES.values())))]
df = pd.concat([df, to_drop, to_drop]).drop_duplicates(keep=False)
print("Keeping " + str(len(multiregion.index) - len(to_drop.index)) + " multi-region/world projects related to IFI countries (out of " + str(len(multiregion.index)) + ")")

# Calculate duration
df['Approval Date'] = pd.to_datetime(df['Approval Date'], infer_datetime_format=True).dt.tz_localize(None)
df['Closing Date'] = pd.to_datetime(df['Closing Date'], infer_datetime_format=True).dt.tz_localize(None)

# project duration = closing date - board approval date (in years, rounded to 2 decimals)
# (only populated if there *is* a closing date, otherwise duration is null)
df['Project Duration'] = df.apply(lambda x: round((x['Closing Date'] - x['Approval Date']).days / 365.25, 2) if pd.notnull(x['Closing Date']) else None, axis=1)

# Remove time from dates
df['Approval Date'] = df['Approval Date'].dt.date
df['Closing Date'] = df['Closing Date'].dt.date

# Combine sectors 2 & 3 and themes 1 & 2 into Additional Sectors
sector_df = df.filter(['Sector 2', 'Sector 3', 'Theme 1', 'Theme 2'], axis=1)
sector_df = sector_df.apply(lambda x: None if x.isnull().all() else '; '.join(x.dropna()), axis=1)
df['Additional Sectors'] = sector_df
df.drop(columns=[ 'Sector 2', 'Sector 3', 'Theme 1', 'Theme 2'], axis=1, inplace=True)

# index indexes into the df but has skips, count is a sequential counter with no relation to the df
count = 0
for index, row in df.iterrows():
    if DEBUG:
        print("Getting contact information for #{0}, project ID {1}".format(count, row["Project ID"]))
    response = json.loads(get_html(PROJECT_API + row['Project ID']).text)
    team_lead = response['projects'][row['Project ID']]['teamleadname']
    team_lead = team_lead.replace(',', ', ').replace('NIL', '')
    if DEBUG:
        print(team_lead)
    df.at[index, 'Project Contact'] = team_lead
    count = count + 1
    # Only run for 20 if debugging
    if DEBUG and count >= DEBUG_NUM_PROJECTS:
        break

# Write to output file
print("Writing the filtered project list to " + FILTERED_PROJECT_LIST)
df.to_excel(open(FILTERED_PROJECT_LIST, 'wb'), index=False, na_rep='')
print("Done")