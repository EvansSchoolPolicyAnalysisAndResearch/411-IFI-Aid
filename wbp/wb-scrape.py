#!/usr/bin/env python3
"""	Download data from the World Bank's Project API
"""
__copyright__ = """
Copyright 2021 Evans Policy Analysis and Research Group (EPAR).
"""
__license__ = """
This project is licensed under the 3-Clause BSD License. Please see the 
license.txt file for more information.
"""
#Imports
import pandas as pd
import requests

#Constants
DEBUG = False
PROJECT_LIST_URL = 'https://search.worldbank.org/api/projects/all.xls'
PROJECT_LIST = './all.xls'
FILTERED_PROJECT_LIST = './filtered.xlsx'
PROJECT_API	=	"http://search.worldbank.org/api/v2/projects?format=json&fl=id,project_abstract,boardapprovaldate,closingdate&source=IBRD&id="
DROP_COLUMNS = ['Region', 'Consultant Services Required', 'IBRD Commitment ', 'IDA Commitment', 
    'Grant Amount','Environmental Assessment Category','Environmental and Social Risk']
RENAME_COLUMNS = {'Project Status':'Status', 'Project Development Objective ':'Description', 
    'Project Closing Date':'Closing Date','Total IDA and IBRD Commitment':'Commitment Amount (USD)'}

#Key = WB country name format, Value = IFI project country name format
IFI_COUNTRIES = { 'Republic of Angola': 'Angola','Republic of Benin' : 'Benin','Republic of Botswana' : 'Botswana',
'Burkina Faso' : 'Burkina Faso','Republic of Burundi' : 'Burundi','Republic of Cameroon' : 'Cameroon',
'Republic of Cabo Verde' : 'Cabo Verde','Central African Republic' : 'Central African Republic',
'Republic of Chad' : 'Chad','Union of the Comoros' : 'Comoros',
"Republic of Cote d'Ivoire" : "Côte d'Ivoire",'Democratic Republic of the Congo' : 'Democratic Republic of the Congo',
'Republic of Equatorial Guinea' : 'Equatorial Guinea','State of Eritrea' : 'Eritrea',
'Kingdom of Eswatini' : 'Eswatini','Federal Democratic Republic of Ethiopia' : 'Ethiopia',
'Gabonese Republic' : 'Gabon','Republic of The Gambia' : 'Gambia','Republic of Ghana' :  'Ghana','Republic of Guinea' : 'Guinea',
'Republic of Guinea-Bissau' : 'Guinea-Bissau','Republic of Kenya' : 'Kenya',
'Kingdom of Lesotho' : 'Lesotho','Republic of Liberia' : 'Liberia',
'Republic of Madagascar' : 'Madagascar','Republic of Malawi' : 'Malawi',
'Republic of Mali' : 'Mali','Islamic Republic of Mauritania' : 'Mauritania',
'Republic of Mauritius' : 'Mauritius','Republic of Mozambique' : 'Mozambique',
'Republic of Namibia' : 'Namibia','Republic of Niger' : 'Niger',
'Federal Republic of Nigeria' : 'Nigeria','Republic of Congo' : 'Republic of Congo',
'Republic of Rwanda' : 'Rwanda','Democratic Republic of Sao Tome and Pricipe' : 'Sao Tome and Principe',
'Republic of Senegal' : 'Senegal','Republic of Seychelles' : 'Seychelles',
'Republic of Sierra Leone' : 'Sierra Leone','Republic of South Africa' : 'South Africa',
'Republic of South Sudan' : 'South Sudan','United Republic of Tanzania' : 'Tanzania',
'Republic of Togo' : 'Togo','Republic of Uganda' : 'Uganda',
'Republic of Zambia' : 'Zambia','Republic of Zimbabwe' : 'Zimbabwe'}

if not DEBUG:
    #Download the excel spreadsheet from the world bank website
    print("Downloading projects spreadsheet from the WB website")
    r = requests.get(PROJECT_LIST_URL)
    print("Download complete!")
    unfiltered_projs = open(PROJECT_LIST, 'wb')
    unfiltered_projs.write(r.content)
    unfiltered_projs.close()
    print("Writing unfiltered projects to " + PROJECT_LIST)

print("Filtering to active projects in IFI countries")
#Read in the unfiltered list of projects
df = pd.read_excel(PROJECT_LIST, header=1)
#Drop unneeded variables and rename others
df.drop(DROP_COLUMNS, axis=1, inplace=True)
df.rename(columns=RENAME_COLUMNS, inplace=True)
#Drop non-IFI countries
df = df[df['Country'].isin(IFI_COUNTRIES.keys())]
#Standardize country names to IFI project format
df = df.replace(IFI_COUNTRIES)
#Drop inactive projects (possible states: Active, Pipeline, Dropped, Closed)
#***TODO: discuss whether or not pipeline should be included
df = df[df['Status'].isin(['Active', 'Pipeline'])]

#Calculate duration
df['Board Approval Date'] = pd.to_datetime(df['Board Approval Date'], infer_datetime_format=True)
df['Closing Date'] = pd.to_datetime(df['Closing Date'], infer_datetime_format=True)
#Make a 'Project Duration' variable that is 'Closing Date' minus 'Board Approval Date' converted into years 
# and rounded to 2 decimals places (only if there *is* a closing date, otherwise leave the duration empty)
df['Project Duration'] = df.apply(lambda x: round((x['Closing Date'] - x['Board Approval Date']).days / 365.25, 2) if pd.notnull(x['Closing Date']) else None, axis=1)
#Remove time from dates
df['Board Approval Date'] = df['Board Approval Date'].dt.date
df['Closing Date'] = df['Closing Date'].dt.date

print("Writing the filtered project list to " + FILTERED_PROJECT_LIST)
df.to_excel(open(FILTERED_PROJECT_LIST, 'wb'), index=False, na_rep='')
print("Done")