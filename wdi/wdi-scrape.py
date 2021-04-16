#!/usr/bin/env python3

# wdi-scrape.py

"""	Download data from the World Bank's World Development Indicator api."""

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

if __name__ == "__main__":
	pars = argparse.ArgumentParser(
		description = __doc__, 
		epilog = __copyright__ + __license__,
		formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	pars.add_argument(
		"-c", "--countries",
		help = "path/filename for a csv with ISO codes and country names",
		type = argparse.FileType('r'),
		default = "country-list.csv",
		dest = "ctry")
	pars.add_argument(
		"-i", "--indicators",
		help = "path/filename for a list of wdi indicators",
		type = argparse.FileType('r'),
		default = "wdi-inds.csv",
		dest = "ind")
	pars.add_argument(
		"-o", "--output",
		help = "path/filename for csv output file",
		type = argparse.FileType('w'),
		default = sys.stdout,
		metavar = "OUTPUT",
		dest = "out")
	pars.add_argument("-y", "--years",
		nargs = "+",
		help = "years for which data should be downloaded e.g. 2009",
		metavar = "YEARS",
		dest = "yrs")
	args = pars.parse_args()

	API_BASE = "http://api.worldbank.org/v2/country/{ctry}/indicator/{ind}?date={yr}&format=json"

	# load the input data from disk
	data = {r["iso"] : {"iso" : r["iso"], "country": r["name"], } 
		for r in csv.DictReader(args.ctry) if r != ""}
	ctry = ";".join(data.keys())
	inds = {r["code"] : r["name"] for r in csv.DictReader(args.ind) if r != ""}
	fields = {"iso": True, "country": True}
	for i, name in inds.items():
		for yr in args.yrs:
			resp = requests.get(
				API_BASE.format(ctry = ctry, ind = i, yr = yr)).json()[1]
			for c in resp:
				field = name + "_" + c["date"]
				fields[field] = True
				data[c["countryiso3code"]][field] = c['value']
	fields = fields.keys()
	w = csv.DictWriter(args.out, fields, extrasaction = "ignore")
	w.writeheader()
	for k in data: w.writerow(data[k])
