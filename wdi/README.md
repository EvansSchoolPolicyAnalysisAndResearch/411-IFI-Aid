wdi-scrape.py
=============

This script downloads indicators from the World Bank's Data API. All of their
myriad data bases appear to use the same API (e.g. World Development Indicators,
World Governance Indicators, etc.) allowing this script to download from any of
them without modification. Data is output in a wide format with a user
specified indicator name with the year appended to it (*name*_*year*). Each
row of the output represents a single country's data. 

Use
---

To run the file enter the following at the terminal:

```bash
python3 wdi-scrape.py -c <country_list> -i <indicator_list> -o <output_file> -y <years>

```

The country list should be a csv file with two columns `iso` and `name`. Each
row of the csv file represents a single country to download data for from the 
World Bank's data API. `iso` is the 3 letter ISO code for the country, and
`name` represents a user readable name for the country. The default value is
`country-list.csv`. A header row is required. See the proviced 
`country-list.csv` for an example of how to properly format this file.

The indicator list is a 2 column csv file with the fields `code`, and `name`.
`code` is the indicator code used by the World Bank Data API system.
The easiest way to obtain the codes is using the World Bank's [databank][bank].
`name` is the column name to be used in the output. It should not contain
spaces, but it should be easily understood. A header row is required. The
default value for the indicator list is `wdi-inds.csv`. The provided version
of this file demonstrates the proper format for the input.

Years represents which years of data to download. Multiple years can be
specified by placing a space between the years, e.g. 2008 2009. A year range
can be specified by separating the starting and ending year by a colon, e.g.
2008:2015 would download data from 2008 - 2015 (inclusive). A mix of both
methods is also acceptable, e.g. 2004 2006 2008:2012 would download data from
2004, 2006, 2008, 2009, 2010, 2011, and 2012.


Modifying the Makefile
----------------------

If you wish to modify the makefile to specify different input and output files
modify the following lines from the makefile

```make
CTRYS	= wdi/country-list.csv
YEARS	= 2019 2009 2018 2008

WDIIN	= wdi/wdi-inds.csv
WDIOUT	= data/wdi-data.csv

WDIDB	= data/wdi-test.csv
WDIDBIN	= wdi/wdi-short.csv

```

For reference the variables are used in the following manner

<dl>
<dt>CTRYS</dt>
<dd>The input file specifying the list of countries for full standard and
debug runs of `wdi-scrape.py`</dd>
<dt>YEARS</dt>
<dd> The years of data to download for full standard and debug runs of
`wdi-scrape.py`</dd>
<dt>WDIIN</dt>
<dd> The indicator input file for a full standard run of `wdi-scrape.py`</dd>
<dt>WDIOUT</dt>
<dd> The output file for a full standard run of `wdi-scrape.py`</dd>
<dt><WDIDB/dt>
<dd> The output file for a debug run of `wdi-scrape.py`</dd>
<dt>WDIDBIN</dt>
<dd> The indicator input file for a debug run of `wdi-scrape.py`</dd>
</dl>

<!-- Links -->

[bank]: https://databank.worldbank.org/source/world-development-indicators#