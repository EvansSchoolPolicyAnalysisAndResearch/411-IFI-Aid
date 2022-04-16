# International Financial Institution Data Scraping

This repository contains scripts that scrape data from several International Financial Institutions (IFIs). These scripts were written to capture data available on IFIs' project web pages but not available in their offered bulk download files. The exception is the WDI scraper which downloads data from the World Bank's World Development Indicators (wdi) API in a format more easily interpreted in certain statistical processing software. 

The World Development Indicators (wdi) script only accesses the public World Bank APIs; the remaining three scripts -- African Development Bank (afdb), International Fund for Agricultural Development (ifad), and World Bank Project (wbp) -- scrape the organization's project websites for additional data.

## Running the scripts

All scripts require python (and only python) and output their resulting data into `/data`. 

The parent script `run_all.py` runs each script one at a time and compiles their results into a single spreadsheet (`./data/ifi_data.xlsx`). To run this script and generate all output use the following command in this directory (i.e., `./411-IFI-Aid`):

```python 
python run_all.py
```

## Running scripts individually

Running scripts individually is usually only necessary if only one data source needs updating or a particular script is not working properly. Run the scripts individually using the following commands:

```python
# AfDB script
python afdb/afdb_scrape.py

# IFAD script
python ifad/ifad_scrape.py

# WBP script
python wbp/wbp_scrape.py
```

## Debugging

Each script has a debug flag that, when set, reduces the number of projects visited and avoids accessing the IFIs website when possible. This flag should not be set unless actively changing/updating the scripts. To debug, simply add "-debug" to the end of any run command (e.g. `python run_all.py -debug`). This flag will make the scripts pull the first five projects from each IFI to reduce time spent when debugging the scripts.

# Links

### African Development Bank (AfDB)

https://www.afdb.org/en/projects-and-operations

### IFAD (International Fund for Agricultural Development)

https://www.ifad.org/en/web/operations/projects-and-programmes

### WDI (World Development Indicators)

https://databank.worldbank.org/source/world-development-indicators

### WBP (World Bank Projects)

https://projects.worldbank.org/en/projects-operations/projects-home
