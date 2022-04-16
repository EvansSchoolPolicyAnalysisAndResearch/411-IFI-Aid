#!/usr/bin/env python3
""" Run all scripts (AfDB, IFAD, WBP, WDI)
"""
__copyright__ = """
Copyright 2021 Evans Policy Analysis and Research Group (EPAR).
"""
__license__ = """
This project is licensed under the 3-Clause BSD License. Please see the 
license.txt file for more information.
"""
# Imports
import os
import subprocess
import sys
import pandas as pd

# Constants
DEBUG = "" if len(sys.argv) == 1 or sys.argv[1] != '-debug' else '-debug'
# Runs all IFI scrapes if true, otherwise uses already generated IFI data files
RUN_SCRAPES = False

CLIMATE_SEARCH_STRING = 'climate|carbon|sequester'
IFIS = ["wdi", 'ifad', "wbp", "afdb"] # Ordered from shortest to longest scrape time
OUTPUT_FILE = 'data/ifi_data.xlsx'

#MAIN
print('Downloading dependencies')
subprocess.call('pip install -r requirements.txt -q')
cwd = os.getcwd()
print('Current working directory: {0}'.format(cwd))

df = pd.DataFrame()
#This loop depends on subdirectories/scripts following the naming convention: "./<ifi_name>/<ifi_name>_scrape.py"
for ifi in IFIS:
    if RUN_SCRAPES:
        print("\n====================")
        print('Running {0} scraper'.format(ifi.upper()))
        print("====================\n")
        code = subprocess.call('python {0}/{0}_scrape.py {1}'.format(ifi, DEBUG))
        if code == 0:
            print('{0}_scrape.py ran successfully'.format(ifi))
        else:
            print ('{0} scrape returned an error ({1}), see output and {2}_scrape.py for further information.'.format(ifi.upper(), code, ifi))
            print('Stopping')
            exit()
    # WDI data not project-level data, don't append to project-level sheet
    if ifi != 'wdi':
        df = pd.concat([df, pd.read_excel('data/{0}_data.xlsx'.format(ifi))], ignore_index=True)

# Generate climate flag (boolean: does climate search string match title, description, or sectors?)
df['Climate Flag'] = 0
df.loc[df['Project Title'].fillna(value='').str.contains(CLIMATE_SEARCH_STRING,case=False) ,'Climate Flag'] = 1
df.loc[df['Description'].fillna(value='').str.contains(CLIMATE_SEARCH_STRING,case=False) ,'Climate Flag'] = 1
df.loc[df['Primary Sector'].fillna(value='').str.contains(CLIMATE_SEARCH_STRING,case=False) ,'Climate Flag'] = 1
df.loc[df['Additional Sectors'].fillna(value='').str.contains(CLIMATE_SEARCH_STRING,case=False) ,'Climate Flag'] = 1

print('All scrapes done -- merging into single spreadsheet. If this step fails, fix the issue, then re-run this script with RUN_SCRAPES set to false to skip scraping the IFI data again!')
df.to_excel(OUTPUT_FILE, index=True, index_label='#', na_rep='', float_format='%.2f')