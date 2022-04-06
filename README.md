# International Financial Institution Data Scraping

This repository represents a series of scripts written to scrape data from a variety of International Financial Institutions (IFIs). These scripts were written to capture data available on project web pages but not available in the bulk download files offered by the sites in question. The exception is the WDI scraper which downloads data from the World Bank's World Development Indicators (wdi) API in a format more easily interpreted in certain statistical processing software. 

The scripts that scrape World Bank data --- World Bank Project (wbp) and World Development Indicators (wdi) --- access the 
public World Bank APIs; the African Development Bank (afdb) and International Fund for Agricultural Development (ifad) scrapers the organization's project websites, with delays in accordance with the site's robots.txt file.

## Running the scripts

All scripts require python (and only python) and output their resulting data into `/data`. 

The parent script `run_all.py` simply runs each script one at a time. To run this script and generate all output use the following command in this directory (i.e., `./411-IFI-Aid`):

```python 
python run_all.py
```

## Running scripts individually

Running scripts individually is usually only necessary if only one data source needs updating or a particular script is not working properly. Each script has a `DEBUG` flag that, when set, reduces the number of projects visited and avoids accessing the IFIs website when possible. This flag should be set to False unless actively changing/updating the scripts.

Running one script can be done by using the following command *in the directory of that script* (e.g., run the AfDB script in `411-IFI-Aid/afdb`)

```python
python <script_name>.py
```

# Links

### African Development Bank (AfDB)

https://www.afdb.org/en/projects-and-operations

### IFAD (International Fund for Agricultural Development)

https://www.ifad.org/en/web/operations/projects-and-programmes

### WDI (World Development Indicators)

https://databank.worldbank.org/source/world-development-indicators

### WBP (World Bank Projects)

https://projects.worldbank.org/en/projects-operations/projects-home