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

# Constants
DEBUG = True
IFIS = ["ifad", "wbp", "wdi", "afdb"]

#MAIN
print("Downloading dependencies")
subprocess.call("pip install -r requirements.txt -q")
cwd = os.getcwd()
print("Current working directory: {0}".format(cwd))

#This loop depends on subdirectories/scripts following the naming convention of: "./<ifi_name>/<ifi_name>_scrape.py"
for ifi in IFIS:
    print("\n====================")
    print("Running {0} scraper".format(ifi.upper()))
    print("====================\n")
    code = subprocess.call("python {0}/{0}_scrape.py {1}".format(ifi, DEBUG))
    if code == 0:
        print("{0}_scrape.py ran successfully".format(ifi))
    else:
        print ("{0} scrape returned an error ({1}), see output and {2}_scrape.py for further information.".format(ifi.upper(), code, ifi))
        print("Stopping")
        exit()

print('All done!')