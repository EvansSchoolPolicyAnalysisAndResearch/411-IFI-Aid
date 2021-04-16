# World Bank Project Data variables
WBP		= wbp/wb-scrape.py 
WBPIN	= wbp/wb-ids.txt
WBPOUT	= data/wbp-data.csv

WBPDB	= data/wbp-test.csv
WBPDBIN	= wbp/wb-short.txt

# WDI download variables
WDI		= wdi/wdi-scrape.py
CTRYS	= wdi/country-list.csv
YEARS	= 2019 2009 2018 2008

WDIIN	= wdi/wdi-inds.csv
WDIOUT	= data/wdi-data.csv

WDIDB	= data/wdi-test.csv
WDIDBIN	= wdi/wdi-short.csv

.PHONY: all

all: $(WDIOUT) $(WBPOUT) 

$(WBPOUT): $(WBP) $(WBPIN)
	@echo --- Downloading World Bank Project Data ---

	@python3 $(WBP) --input $(WBPIN) --output $(WBPOUT)


$(WDIOUT): $(CTRYS) $(WDIIN) $(WDI)
	@echo --- Downloading WDI Data ---

	@python3 $(WDI) --countries $(CTRYS) --indicators $(WDIIN)\
	 --output $(WDIOUT) --years $(YEARS)

.PHONY: debug

debug: $(WDIDB) $(WBPDB)

$(WBPDB): $(WBP) $(WBPDBIN)
	@echo --- Running World Bank Project Debug List ---
	
	@python3 $(WBP) --input $(WBPDBIN) --output $(WBPDB)

$(WDIDB): $(CTRYS) $(WDIDBIN) $(WDI)
	@echo --- Running WDI Debug List ---
	
	@python3 $(WDI) --countries $(CTRYS) --indicators $(WDIDBIN)\
	 --output $(WDIDB) --years $(YEARS)


.PHONY: clean

clean:
	rm $(WDIDB) $(WBPDB) 
