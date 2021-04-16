wb-scrape.py
============

This script uses the World Bank's Project API to download information not
available as part of the bulk project data download. The downloaded information
includes:

- Project Abstract,
- Planned Closing Date, and
- Board Approval Date.

All of the required dependencies should be part of the Python Standard Library.

Use
---

Run the Script from the command line using the following format:


```bash
python wb-scrape.py -i <input_file> -o <output_file>
```

By default the script reads the input from standard in (stdin) and outputs to
standard out (stdout). If this file is run from the makefile provided in the
parent directory it is run with `wb-ids.txt` as the input file and 
`../data/wbp-data.csv` as the output destination. If `debug` is the make target
rather than `all` `wb-short.txt` is used as the input file and `wbp-test.csv` 
is used for the output file.


Modifying the Makefile
----------------------

If you wish to modify the makefile to specify different input and output files
modify the following lines from the makefile

```make
WBPIN	= wbp/wb-ids.txt
WBPOUT	= data/wbp-data.csv

WBPDB	= data/wbp-test.csv
WBPDBIN	= wbp/wb-short.txt

```

For reference the variables are used in the following manner

<dl>
<dt>WBPIN</dt>
<dd>The input file for a full standard run of `wb-scrape.py`</dd>
<dt>WBPOUT</dt>
<dd>The output file for a full standard run of `wb-scrape.py`</dd>
<dt>WBPDB</dt>
<dd>The output file for a debug run of `wb-scrape.py`</dd>
<dt>WBPDBIN</dt>
<dd>The input file for a debug run of `wb-scrape.py`</dd>
</dl>
