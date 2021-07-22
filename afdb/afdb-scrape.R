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
# inputs: a file containing a list of relevant project numbers                 #
# outputs: a csv file containing project numbers, description, planned         #
#          completion date, and dac sector codes                               #
################################################################################

# IMPORTS #
# install.packages("tidyverse")
# install.packages("xml2")
# install.packages("magrittr")
# install.packages("rvest")
# install.packages("sjmisc")
library(magrittr)
library(readxl)
library(rvest)
library(sjmisc)
library(tidyverse)
library(xml2)

# CONSTANTS #
DEBUG <- TRUE
BASE_URL <- "https://projectsportal.afdb.org/dataportal/VProject/show/"
PROJECTS_FILE <- if(DEBUG) "afdb-short.txt" else "afdb-ids.txt"
OUTPUT_FILE <- if(DEBUG) "../data/afdb_test.csv" else "../data/afdb_data.csv"
DAC_FILE <- "../DAC-CRS-CODES.xls"

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
get_dac5_desc <- function(dac_code){
  print(dac_lookup_df)
  return("TODO")
}

# MAIN #
proj_ids <- read_lines(PROJECTS_FILE, skip_empty_rows = TRUE)
dac_lookup_df <- read_excel(DAC_FILE, sheet=12, skip=2)

# create a dataframe to hold the scraped data.
data <- data.frame(matrix(ncol = 17, nrow = 0))
names(data) <- c(
  "Project ID",
  "Country",
  "Project Title",
  "Description",  
  "Commitment in U.A.",
  #"Status",
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
for(id in proj_ids) {
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
  
  ##############################
  # parse the web page results #
  ##############################
  # pull info from main web page table, only look at active projects
  status <- main_table_parse(page, "Status")
  if(status != "Implementation" && status != "Approved"){
    if(DEBUG) print(paste("Skipping inactive project:", id))
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
  
  if(DEBUG) print(paste(id, country, project, commitment, approval_date, completion_date, duration, funding, sector, sov, dac, dac5, dac5_desc, dac5_desc_detailed, contact_name, contact_email, sep="; "))
  # add parsed data into the main data frame
  data[nrow(data) + 1,] <- c(id, country, project, desc, commitment, approval_date, completion_date, duration, funding, sector, sov, dac, dac5, dac5_desc, dac5_desc_detailed, contact_name, contact_email)
  
  # calculate elapsed time for request
  elapsed <- Sys.time() - start
  # Respect the robots.txt - only do a request every 10 seconds
  if(elapsed < 10) {
    Sys.sleep(10-elapsed)
  }
}

# Write to disk
written <- FALSE
count <- 0
while(!written && count < 20){
	written <- write_file(data, OUTPUT_FILE)
	count <- count + 1
}

print("All done!")