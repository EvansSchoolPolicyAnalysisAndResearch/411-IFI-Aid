afdb_scrape.R
=============

`afdb_scrape.R` scrapes the AFDB Project pages. It depends on the following
libraries:

- `readxl`,
- `rvest`,
- `R.utils`,
- `sjmisc`, and
- `xml2`

Please install them before running the script.

Purpose
-------

This script was written to scrape bulk project data from the 
African Development Bank (AfDB). 

Use
---

By default the script outputs a csv to `../data/afdb_data.csv`. The output csv contains one line
per project. Due to the AfDB's robots.txt requests are only made to the server every
10 seconds. Scraping a large number of projects can take multiple hours. To keep
track of progress the script outputs the current project number to the terminal
as it runs. 

The output files can be modified by changing the value of the `OUTPUT_FILE` 
(output) at the top of the code (see the [modifying paths](#modifying-paths) 
section for more information). These values are also modified by the `debug` 
variable found in the file. The effect and purpose of the debug flag is further 
described in the [following section](#debug-flag).

Debug Flag
----------

The `DEBUG` variable is a boolean value. If set to `FALSE` the code runs on the 
full set of inputs (downloaded from the AfDB webpage) and outputs to `../data/afdb_data.csv`. 
When `debug` is set to `TRUE` it reads input from `afdb_ids_short.xlsx` 
and outputs to `afdb_test.csv`. It also includes additional output to the terminal. 
This was created to test the script without having to run on the full list of AfDB 
projects. The list provided with this file can take up to 10 hours to run due to 
the requested delay (explained in [Use](#use)) between requests. 

Modifying Paths
---------------

In order to accommodate the `debug` flag paths are set using an if statement.
This can be confusing if you are not used to this style. The simple system for
modifying paths is the first of the two strings is the `debug` file path and the
second of the two paths is the standard file path. See the example below

### Example

By default the lines setting the path look like this:

```{r}
	OUTPUT_FILE <- if(DEBUG) "../data/afdb_test.csv" else "../data/afdb_data.csv"
```

If we wanted to modify this to output to a file called `project_info.csv` in the
same folder as the script we could change the code to:

```{r}
	OUTPUT_FILE <- if(DEBUG) "../data/afdb_test.csv" else "project_info.csv"
```
