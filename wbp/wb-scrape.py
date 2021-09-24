#!/usr/bin/env python3

"""	Download data from the World Bank's Project API which are not included in
    the bulk project data download available on their website.
"""

import argparse
import csv
import pandas as pd
import requests
import sys

__copyright__ = """
Copyright 2021 Evans Policy Analysis and Research Group (EPAR).
"""
__license__ = """
This project is licensed under the 3-Clause BSD License. Please see the 
license.txt file for more information.
"""
DEBUG = True
PROJECT_LIST_URL = 'https://search.worldbank.org/api/projects/all.xls'
PROJECT_LIST = './all.xls'
FILTERED_PROJECT_LIST = './filtered.xlsx'
PROJECT_API	=	"http://search.worldbank.org/api/v2/projects?format=json&fl=id,project_abstract,boardapprovaldate,closingdate&source=IBRD&id="

#Key = WB country name format, Value = IFI project country name format
IFI_COUNTRIES = {
'Republic of Angola': 'Angola','Republic of Benin' : 'Benin','Republic of Botswana' : 'Botswana',
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
'Republic of Zambia' : 'Zambia','Republic of Zimbabwe' : 'Zimbabwe'
}


def get_proj_ids(url):
    if not DEBUG:
        r = requests.get(url)
        unfiltered_projs = open(PROJECT_LIST, 'wb')
        unfiltered_projs.write(r.content)
        unfiltered_projs.close()

    #Read in the unfiltered list of projects
    df = pd.read_excel(PROJECT_LIST, header=1)
    #Drop non-IFI countries
    df = df[df['Country'].isin(IFI_COUNTRIES.keys())]
    #Standardize country names to IFI project format
    df = df.replace(IFI_COUNTRIES)
    #Drop inactive projects (possible states: Active, Pipeline, Dropped, Closed)
    #***TODO: discuss whether or not pipeline should be included
    df = df[df['Project Status'].isin(['Active', 'Pipeline'])]

    df.to_excel(open(FILTERED_PROJECT_LIST, 'wb'), index=False, na_rep='')
    print("Done")

def project_scraper(url):
    # perform all the api calls using list comprehension on the id list
    # this was probably a dumb idea. it wwould have been smarter to use a loop
    # and do the small amount of cleaning necessary in the same loop.
    get_proj_ids(url)
    

get_proj_ids(PROJECT_LIST_URL)

    # data = [requests.get(PROJECT_API + i).json()['projects'][i] 
    #     for i in ids if not i == '']

    # # cleaning and standardizing the api results
    # for a in data:
    #     # check if a project abstract was found
    #     if not 'project_abstract' in a.keys():
    #         # if no abstract add a blank one to the dict
    #         a['project_abstract'] = ''
    #     else:
    #         # if yes unpack the payload from the dict in a dict that the
    #         # json response provides (how rude)
    #         a['project_abstract'] = a['project_abstract']['cdata']
    # return data

# if __name__ == '__main__':
#     pars = argparse.ArgumentParser(
#         description = __doc__, 
#         epilog = __copyright__ + __license__,
#         formatter_class=argparse.ArgumentDefaultsHelpFormatter)
#     pars.add_argument(
#         "-i", "--input",
#         default = sys.stdin,
#         help = "filename with a list of wb project ideas",
#         metavar = "INPUT",
#         type = argparse.FileType('r'),
#         dest = "input")
#     pars.add_argument(
#         "-o", "--output",
#         default = sys.stdout,
#         help = "filename for outputting downloaded data (csv)",
#         metavar = "OUTPUT",
#         type = argparse.FileType('w'),
#         dest = "output")
#     args = pars.parse_args()

#     # read in the list of project ids
#     proj_ids = args.input.read().split('\n')

#     data = project_scraper(proj_ids)

#     # write the information to a csv file
#     keys = [i for i in data[0].keys()]
#     w = csv.DictWriter(args.output, keys, extrasaction = 'ignore', )
#     w.writeheader()
#     for a in data: w.writerow(a)
