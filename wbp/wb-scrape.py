#!/usr/bin/env python3

# wbp/wb-scrap.py

"""	Download data from the World Bank's Project API which are not included in
	the bulk project data download available on their website.
"""

__copyright__ = """
Copyright 2021 Evans Policy Analysis and Research Group (EPAR).
"""

__license__ = """
This project is licensed under the 3-Clause BSD License. Please see the 
license.txt file for more information.
"""

import requests
import csv
import argparse
import sys

PROJECT_API	=	"http://search.worldbank.org/api/v2/projects?format=json&fl=id,project_abstract,boardapprovaldate,closingdate&source=IBRD&id="

def project_scraper(ids):
	# perform all the api calls using list comprehension on the id list
	# this was probably a dumb idea. it wwould have been smarter to use a loop
	# and do the small amount of cleaning necessary in the same loop.
	data = [requests.get(PROJECT_API + i).json()['projects'][i] 
		for i in ids if not i == '']

	# cleaning and standardizing the api results
	for a in data:
		# check if a project abstract was found
		if not 'project_abstract' in a.keys():
			# if no abstract add a blank one to the dict
			a['project_abstract'] = ''
		else:
			# if yes unpack the payload from the dict in a dict that the
			# json response provides (how rude)
			a['project_abstract'] = a['project_abstract']['cdata']
	return data

if __name__ == '__main__':
	pars = argparse.ArgumentParser(
		description = __doc__, 
		epilog = __copyright__ + __license__,
		formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	pars.add_argument(
		"-i", "--input",
		default = sys.stdin,
		help = "filename with a list of wb project ideas",
		metavar = "INPUT",
		type = argparse.FileType('r'),
		dest = "input")
	pars.add_argument(
		"-o", "--output",
		default = sys.stdout,
		help = "filename for outputting downloaded data (csv)",
		metavar = "OUTPUT",
		type = argparse.FileType('w'),
		dest = "output")
	args = pars.parse_args()

	# read in the list of project ids
	proj_ids = args.input.read().split('\n')

	data = project_scraper(proj_ids)

	# write the information to a csv file
	keys = [i for i in data[0].keys()]
	w = csv.DictWriter(args.output, keys, extrasaction = 'ignore', )
	w.writeheader()
	for a in data: w.writerow(a)
