International Financial Institution Data Scraping
=================================================

This repository represents a series of scripts written to scrape data from a 
variety of International Financial Institutions. These scripts were written
to capture data available on project web pages but not available in the bulk
download files offered by the sites in question. The exception is the WDI 
scraper which downloads data from the World Bank's World Development Indicators
(wdi) API in a format more easily interpreted in certain statistical processing 
software. 

The World Bank Scrapers --- World Bank Project (wbp) and wdi --- access the 
public World Bank APIs and are written in Python. The African Development bank
(afdb) scraper was written in R and scrapes the site itself, with delays in
accordance with the site's robots.txt file.

Makefile
--------

The provided makefile runs the python scrapers with a default set of input and 
output files and settings, as well as a debug option. The afdb scraper is not
run because of differences in how R is used in practice (often from within R
Studio and not as stand alone scripts.) For more information on how to run the
scripts manually please see the README.mds in each individual folder.

The makefile was written to work with GNU Make v4.2.1

the makefile contains the following targets:

```make all```

a target which runs both `data/wdi-data.csv` and `data/wbp-data.csv`.


```make data/wdi-data.csv```

Runs the `wdi/wdi-scraper.py` with `wdi/country-list.csv` as the country input,
and `wdi-inds.csv` as the list of indicators. output is saved in 
`data/wdi-data.csv`.

```make data/wbp-data.csv```

Runs `wbp/wb-scraper.py` with `wbp/wb-ids.txt` as the input file and saves 
the output to `data/wbp-data.csv`

```make debug```

A target which runs both `data/wbp-test.csv` and `data/wdi-test.csv`.

```make data/wdi-test.csv```

Runs the `wdi/wdi-scraper.py` with `wdi/country-list.csv` as the country input,
and `wdi-short.csv` as the list of indicators. output is saved in 
`data/wdi-test.csv`.

```make data/wbp-test.csv```

Runs `wbp/wb-scraper.py` with `wbp/wb-short.txt` as the input file and
saves the output to `data/wbp-test.csv`

```make clean```

Removes `data/wbp-test.csv` and `data/wdi-test.csv`. It does not remove the 
full downloads because it would really suck to have to run everything again if 
you don't have to.