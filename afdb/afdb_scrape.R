#!/usr/bin/env Rscript

################################################################################
# afdb/afdb-scrape.R                                                           #
#                                                                              #
# Copyright 2021 Evans Policy Analysis and Research Group (EPAR).              #
#                                                                              #
# This project is licensed under the 3-Clause BSD License. Please see the      #
# license.txt file for more information.                                       #
#                                                                              #
# this script crawls the african development bank project pages to create a    #
# database of specified information                                            #
#                                                                              #
#                                                                              #
# inputs: none                                                                 #
# outputs: a csv file containing project numbers, description, planned         #
#          completion date, dac sector codes, etc                              #
################################################################################

# IMPORTS #
# install.packages("readxl")
# install.packages("rvest")
#install.packages("R.utils",repos = "http://cran.us.r-project.org")
# install.packages("sjmisc")
# install.packages("xml2")
library(readxl)
library(rvest)
library(R.utils)
library(sjmisc)
library(xml2)



# CONSTANTS AND OUTPUT #
DEBUG <- FALSE
RATE_LIMIT <- 10
BASE_URL <- "https://projectsportal.afdb.org/dataportal/VProject/show/"
OUTPUT_FILE <- if(DEBUG) "../data/afdb_test.csv" else "../data/afdb_data.csv"
DAC_FILE <- "../DAC-CRS-CODES.xls"
AFDB_SPREADSHEET <- if(DEBUG) "afdb-ids-short.xlsx" else "afdb-ids.xlsx"
AFDB_SPREADSHEET_URL <- "https://projectsportal.afdb.org/dataportal/VProject/exportProjectList?reportName=dataPortal_project_list"
sink("output.txt", split=TRUE, append = FALSE)

# FUNCTIONS #
#Scrape
get_html <- function(url) {
  tryCatch(
    read_html(url),
    error = function(e) {
      cat("Request failed, retrying.\n")
      Sys.sleep(5) 
      NULL
    }
  )
}

# File write
write_file <- function(df, filename) {
  tryCatch(
    {
      df %>% write.csv( 
        file = filename, 
        quote = TRUE)
      TRUE
    },
    error = function(e) {
      cat("writing to file failed, retrying.\n")
      print(e)
      FALSE
    }
  )
}

#Searches every table in the html page for x1's data
all_table_parse <- function(page, x1) {
  ret <- ""
  tables <- page %>% html_nodes("table")
  #For each table on the webpage
  for(i in 1:length(tables)){
    table <- tryCatch({
      tables %>% .[[i]] %>% html_table(header = FALSE, trim=TRUE)
    }, error = function(err){
      if(DEBUG) print(err)
      NULL
    })
    
    if(is.null(tables[[i]]) || length(tables[[i]]) == 0) next
    
    #Does current table have bad formatting?
    if(str_contains(table[['X1']], "\n\t") && !str_contains(table[['X1']], "Download")){
      #Correct formatting using regex (sorry)
      table <- str_replace_all(table[['X1']], "[^\\S ]+[ ]+[^\\S ]+", "***")
      table <- strsplit(table, "\\*\\*\\*")
      #Search through table rows for matches (i.e. filter)
      if(!is.null(table) && length(table) > 0 && str_contains(table, x1)){
        for(j in 1:length(table)){
          if(str_contains(table[[j]][[1]], x1)){
            ret <- paste(ret, table[[j]][[2]], sep = ", ")
          }  
        }
        #Return if we've found the indicator
        if(length(ret) > 0){
          return(substring(ret, first = 3))
        }
      }
      else{
        next
      }
    }
    
    #Current table did not have bad formatting, just search
    if(!is.null(table) && length(table) > 1){
      for(k in 1:length(table)){
        if(str_contains(table[['X1']][k], x1)){
          return (table[['X2']][k])
        }
      }  
    }
  }
  return(NULL)
}

#Cleaner than all_table_parse, but less generalizable
# (only searches the first table in the HTML)
main_table_parse <- function(page, x1) {
  temp <- (page %>% 
             html_node(".table") %>%
             html_table(header = FALSE) %>%
             filter(X1 == x1))
  # check if table had requested data, if not replace with "N/A"
  return (if(nrow(temp) == 0) "N/A" else temp[['X2']])
}

#Looks up the DAC or DAC5 code in the DAC-CRS-CODES excel file
get_dac5_desc <- function(code){
  if(is.null(code) || code == "N/A") return("N/A")
  code <- strtoi(code)
  desc <- if(code < 1000)
            dac_df$DESCRIPTION[which(dac_df$`DAC 5 CODE` == code)] 
          else
            dac_df$DESCRIPTION[which(dac_df$`concatenate` == code)]
  return(if(!is.null(desc)) desc else "N/A")
}

# MAIN #

#If real run, download the projects file from the AFDB website 
if(!DEBUG) download.file(AFDB_SPREADSHEET_URL, AFDB_SPREADSHEET, method="curl") 
proj_ids <- read_excel(AFDB_SPREADSHEET, skip=0)
#Drop projects that aren't in progress. Must be done in 2 steps
proj_ids <- proj_ids[(proj_ids$Status == "Approved" | proj_ids$Status == "Implementation"), ]
proj_ids <- proj_ids[!is.na(proj_ids$`Project Code`), ]
#Read the DAC description excel file
dac_df <- read_excel(DAC_FILE, sheet=12, skip=2)

# create a dataframe to hold the scraped data.
data <- data.frame(matrix(ncol = 18, nrow = 0))
names(data) <- c(
  "Project ID",
  "Country",
  "Project Title",
  "Description",  
  "Commitment in U.A.",
  "Status",
  "Start Date",
  "Closing Date",
  "Project Duration",
  "Source of Financing",
  "Sovereign",
  "Sector",
  "DAC Sector Code",
  "DAC5 Code",
  "DAC5 Description",
  "Detailed Description",
  "Contact Name",
  "Contact Email"
)


# for each id in provided file
for(id in proj_ids$`Project Code`) {
  if(is.null(id) || is.na(id)) next
  
  start <- Sys.time()
  "scraping project" %>% paste(id, "\n", sep = " ") %>% cat()
  page  <- NULL
  count <- 0
  
  # using a loop to retry on failed attempts just in case there is an http
  # request error. only retry 20 times in case there is a bad id that doesn't
  # work (it happened, don't remove the loop limiter)
  while(length(page) == 0 && count < 20){
    page <- get_html(paste(BASE_URL, id, sep=""))
    count <- count + 1
  }
  # if the loop ended because of the loop limiter skip to next id
  if(length(page) == 0) next
  processing_time <- Sys.time()
  ##############################
  # parse the web page results #
  ##############################
  # pull info from main web page table, only look at active projects
  status <- main_table_parse(page, "Status")
  if(status != "Approved" && status != "Implementation"){
    print(paste("Skipping project:", id, "with status:", status))
    next
  }
  
  commitment <- main_table_parse(page, "Commitment")
  commitment <- if (str_length(commitment) > 5) substring(commitment, 5) else commitment
  approval_date <- main_table_parse(page, "Approval Date")
  completion_date <- main_table_parse(page, "Planned Completion Date")
  duration <- round(difftime(as.Date(completion_date, format="%d %b %Y"),
                             as.Date(approval_date, format="%d %b %Y"),
                             units="days")
                    / 365.25, 2)
  duration <- if(!is.null(duration)) duration else "N/A"
  sov <- main_table_parse(page, "Sovereign / Non-Sovereign")

  sector <- main_table_parse(page, "Sector")
  dac <- main_table_parse(page, "DAC Sector Code")
  if(nchar(dac) < 3) dac <- "N/A"
  dac5 = substring(dac, 1,3)
  dac5_desc <- get_dac5_desc(dac5)
  dac5_desc_detailed <- get_dac5_desc(dac)
  
  contact_name <- all_table_parse(page, "Name")
  contact_name <- if (!is.null(contact_name)) str_to_title(contact_name) else "N/A"
  contact_email <- all_table_parse(page, "Email")
  contact_email <- if(!is.null(contact_email)) contact_email else "N/A"
  funding <- all_table_parse(page, "Funding")
  
  #Get country & project names
  country_plus_project <- page %>% html_node("h2") %>% html_text2()
  country_plus_project <- str_replace(country_plus_project, " ?[\\p{Pd}|:] ?", " - ")
  country_plus_project <- str_split(country_plus_project, " - ", n=2)[[1]]
  country <- if(is.na(country_plus_project[1])) "N/A" else country_plus_project[1]
  project <- if(is.na(country_plus_project[2])) "N/A" else country_plus_project[2]
  #If the country exists and the project doesn't, that usually means that the project name was not of the form "country - project"
  if(country != "N/A" && project == "N/A"){
    project <- country
    country <- "N/A"
  }
  #Reassign country to the (standardized) country name from the table
  country <- all_table_parse(page, "Country")
  
  # by default set to n/a will replace later if we find what we're after
  desc <- ""
  # pull out all the divs and put them in a vector like object
  divs <- page %>% html_nodes("div")
  # iterate through the list looking for information
  for(div in divs) {
    if(html_text(html_node(div,"h3")) %in% "Project General Description"){
      desc <- div %>% html_node("p") %>% html_text()
    }
    if(html_text(html_node(div,"h3")) %in% "Project Objectives") {
      desc <- paste(div %>% html_node("p") %>% html_text(), desc, sep="\n\n")
    }
  }
  
  if(DEBUG) print(paste(id, country, project, commitment, status, approval_date, completion_date, duration, funding, sov, sector, dac, dac5, dac5_desc, dac5_desc_detailed, contact_name, contact_email, sep="; "))
  # add parsed data into the main data frame
  data[nrow(data) + 1,] <- c(id, country, project, desc, commitment, status, approval_date, completion_date, duration, funding, sov, sector, dac, dac5, dac5_desc, dac5_desc_detailed, contact_name, contact_email)

  # calculate elapsed time for request
  elapsed <- Sys.time() - start
  # Respect the robots.txt - only do a request every 10 seconds
  printf("Download time: %.2f // Processing time: %.2fs // Sleep time: %.2fs\n", processing_time - start, elapsed - processing_time + start, RATE_LIMIT - elapsed)
  if(elapsed < RATE_LIMIT) {
    Sys.sleep(RATE_LIMIT - elapsed)
  }
}

# Write to disk
written <- FALSE
count <- 0
while(!written && count < 20){
	written <- write_file(data, OUTPUT_FILE)
	count <- count + 1
}

closeAllConnections()
print("All done!")