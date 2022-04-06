################################################################################
# wdi/wdi-scrape.py                                                            #
#                                                                              #
# Copyright 2021 Evans Policy Analysis and Research Group (EPAR).              #
#                                                                              #
# This project is licensed under the 3-Clause BSD License. Please see the      #
# license.txt file for more information.                                       #
#                                                                              #
# This script downloads projects from the World Development Indicators 
# webpage to create a database of specified information                        #
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
import requests
import sys

# Constants
DEBUG = False if len(sys.argv) == 1 else sys.argv[1] == "True"
API_BASE = 'http://api.worldbank.org/v2/country/{ctry}/indicator/{ind}?date={yr}&format=json'
YEARS = ['2009', '2010']
INDICATOR_CSV = './wdi/wdi_inds.csv'
OUTPUT_CSV = './data/wdi_data_debug.csv' if DEBUG else './data/wdi_data.csv'
ISO_CODES = {
    'AGO': 'Angola', 'BEN': 'Benin', 'BWA': 'Botswana','BFA': 'Burkina Faso',
    'BDI': 'Burundi','CMR': 'Cameroon','CPV': 'Cape Verde','CAF': 'Central African Republic',
    'TCD': 'Chad','COM': 'Comoros','COD': 'DRC','COG': 'Republic of Congo',
    'CIV': "Cote d'Ivoire",'GNQ': 'Equatorial Guinea','ERI': 'Eritrea','SWZ': 'Eswatini',
    'ETH': 'Ethiopia','GAB': 'Gabon','GMB': 'Gambia','GHA': 'Ghana','GIN': 'Guinea',
    'GNB': 'Guinea-Bissau','KEN': 'Kenya','LSO': 'Lesotho','LBR': 'Liberia','MDG': 'Madagascar',
    'MWI': 'Malawi','MLI': 'Mali','MRT': 'Mauritania','MUS': 'Mauritius','MOZ': 'Mozambique',
    'NAM': 'Namibia','NER': 'Niger','NGA': 'Nigeria','RWA': 'Rwanda',
    'STP': 'Sao Tome and Principe','SEN': 'Senegal','SYC': 'Seychelles','SLE': 'Sierra Leone',
    'ZAF': 'South Africa','SSD': 'South Sudan','TZA': 'Tanzania','TGO': 'Togo',
    'UGA': 'Uganda','ZMB': 'Zambia','ZWE': 'Zimbabwe'
}

# Use a shorter list of countries if debugging
ISO_CODES = {'AGO':'Angola', 'ETH': 'Ethiopia', 'SSD': 'South Sudan'} if DEBUG else ISO_CODES

# Get dictionary of indicators from csv file
inds = {r["code"] : r["name"] for r in csv.DictReader(open(INDICATOR_CSV)) if r != ""}
# Initialize output data dictionary in the following format for all countries: 
#   "{ISO CODE: {'iso': ISO CODE, 'country': COUNTRY NAME}}"
data = {key: {'iso': key, 'country': value} for key, value in ISO_CODES.items()}
fields = {"iso": True, "country": True}

# Request all country data for each indicator and year
for ind, name in inds.items():
    for yr in YEARS:
        resp = requests.get(API_BASE.format(ctry = ';'.join(ISO_CODES.keys()), ind = ind, yr = yr)).json()[1]
        for c in resp:
            field = name + "_" + c["date"]
            fields[field] = True
            data[c["countryiso3code"]][field] = c['value']
fields = fields.keys()
w = csv.DictWriter(open(OUTPUT_CSV, 'w+', newline=''), fields, extrasaction = "ignore")
for k in data: w.writerow(data[k])

if DEBUG:
    print(data)
w.writeheader()