afdb-scrape.R
=============

`afdb-scrape.R` scrapes the AFDB Project pages. It depends on the following
libraries:

- `tidyverse`,
- `magrittr`,
- `xml2`, and
- `rvest`

Please install them before running the script.

Purpose
-------

This script was written to supplement the bulk project data download from the 
African Development Bank (AfDB). To that end, it only downloads data not
included in those files. Specifically, it downloads

- Project General Description,
- Project Objective,
- DAC Sector Code, and
- Planned Completion Date.

Use
---

By default the script reads a list of AfDB project numbers from `afdb-ids.txt`
and outputs a csv to `../data/afdb-data.csv`. The output csv contains one line
per project with the data described in purpose along with the project's ID
number. Due to the AfDB's robots.txt requests are only made to the server every
10 seconds. Scraping a large number of projects can take multiple hours. To keep
track of progress the script outputs the current project number to the terminal
as it runs. 

The input and output files can be modified by changing the value of the 
`filename` (input) and `output_file` (output) at the top of the code (see the 
[modifying paths](#modifying-paths) section for more information). These 
values are also modified by the `debug` variable found in the file. The effect
and purpose of the debug flag is further described in the 
[following section](#debug-flag).

Debug Flag
----------

The `debug` variable is a boolean value. If set to `FALSE` the code runs on the 
full set of inputs (set by `filename` variable and `afdb-ids.txt` by default)
and outputs to `../data/afdb-data.csv` by default. When `debug` is set to `TRUE`
input is instead read from `afdb-short.txt` and output to `afdb-test.csv`. It 
also includes additional output to the terminal. This was created to test the 
script without having to run on the full list of AfDB projects. The list
provided with this file can take up to 13 hours to run due to following the 
requested delay between requests. 

Modifying Paths
---------------

In order to accommodate the `debug` flag paths are set using an if statement.
This can be confusing if you are not used to this style. The simple system for
modifying paths is the first of the two strings is the `debug` file path and the
second of the two paths is the standard file path. See the example below

### Example

By default the lines setting the path look like this:

```{r}
	filename <- if(debug) "afdb-short.txt" else "afdb-ids.txt"
	ouput_file <- if(debug) "../data/afdb-test.csv" else "../data/afdb-data.csv"
```

If I wanted to modify this to output to a file called `project-info.csv` in the
same folder as the script I would change the second line as follows:

```{r}
	output_file <- if(debug) "../data/afdb-test.csv" else "project-info.csv"
```
