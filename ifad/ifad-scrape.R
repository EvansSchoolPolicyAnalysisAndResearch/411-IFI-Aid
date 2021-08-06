#!/usr/bin/env Rscript

################################################################################
# ifad/ifad-scrape.R                                                           #
#                                                                              #
# Copyright 2021 Evans Policy Analysis and Research Group (EPAR).              #
#                                                                              #
# This project is licensed under the 3-Clause BSD License. Please see the      #
# license.txt file for more information.                                       #
#                                                                              #
# this script crawls International Fund for Agricultural Development project   #
# pages to create a database of specified information                          #
#                                                                              #
#                                                                              #
# inputs: none                                                                 #
# outputs: a csv file containing project numbers, description, planned         #
#          completion date, dac sector codes, etc                              #
################################################################################

# IMPORTS #
# install.packages("tidyverse")
# install.packages("xml2")
# install.packages("magrittr")
# install.packages("rvest")
# install.packages("sjmisc")
#install.packages("R.utils",repos = "http://cran.us.r-project.org")
library(magrittr)
library(readxl)
library(R.utils)
library(rvest)
library(sjmisc)
library(tidyverse)
library(xml2)

# CONSTANTS AND OUTPUT #
DEBUG <- TRUE
BASE_URL <- "https://www.ifad.org/en/web/operations/projects-and-programmes?mode=search"
PROJECT_URL <- "https://www.ifad.int/en/web/operations/-/project/"
OUTPUT_FILE <- if(DEBUG) "../data/ifad_test.csv" else "../data/ifad_data.csv"
DAC_FILE <- "../DAC-CRS-CODES.xls"
IFI_COUNTRIES <- c("Angola", "Benin", "Botswana", "Burkina Faso", "Burundi", "Cameroon",
"Cabo Verde","Central African Republic","Chad","Comoros","Côte d'Ivoire","Democratic Republic of the Congo",
"Equatorial Guinea","Eritrea","Eswatini","Ethiopia","Gabon","Gambia","Gambia (The)", "Ghana","Guinea",
"Guinea-Bissau","Kenya","Lesotho","Liberia","Madagascar","Malawi","Mali","Mauritania",
"Mauritius","Mozambique","Namibia","Niger","Nigeria","Republic of Congo","Rwanda",
"Sao Tome and Principe","Senegal","Seychelles","Sierra Leone","South Africa","South Sudan",
"Tanzania", "United Republic of Tanzania", "Togo","Uganda","Zambia","Zimbabwe")

#sink("ifad-output.txt", split=TRUE, append = FALSE)

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

#Scrape project IDs out of current tab
scrape_rows <- function(page, tab){
  #Get each project's row element
  rows <- page %>% html_nodes(paste("div.tab", tab, sep="")) %>% 
    html_nodes("div.container > div.row") %>% 
    html_nodes("div.project-info-paragraph > a") %>% 
    html_nodes("div.col-md")

  #Filter to projects from relevant countries
  countries <- rows %>% html_nodes("div.col-md-3") %>% html_text()
  is_relevant_country <- countries %in% IFI_COUNTRIES
  
  #Grab project IDs
  ids <- rows %>% html_nodes("div.col-md-2") %>% html_text()
  #Filter out dates
  ids <- ids[!grepl("\\s", ids)]
  #Filter our irrelevant countries
  ids <- ids[is_relevant_country]
  return(ids)
}

# MAIN #
#Read the DAC description excel file
dac_df <- read_excel(DAC_FILE, sheet=12, skip=2)
page <- get_html(BASE_URL)

ids <- scrape_rows(page, 1)
ids <- append(ids, scrape_rows(page, 2))
ids <- append(ids, scrape_rows(page, 3))
print(ids)

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
for(id in ids) {
  if(is.null(id) || is.na(id)) next
  
  start <- Sys.time()
  "scraping project" %>% paste(id, "\n", sep = " ") %>% cat()
  page  <- NULL
  count <- 0
  
  # using a loop to retry on failed attempts just in case there is an http
  # request error. only retry 20 times in case there is a bad id that doesn't
  # work (it happened, don't remove the loop limiter)
  while(length(page) == 0 && count < 20){
    page <- get_html(paste(PROJECT_URL, id, sep=""))
    count <- count + 1
  }
  # if the loop ended because of the loop limiter skip to next id
  if(length(page) == 0) next
  processing_time <- Sys.time()
  ##############################
  # parse the web page results #
  ##############################
  # PULL INFO FROM SITE
  
  
  if(DEBUG) print(paste(id, country, project, commitment, approval_date, completion_date, duration, funding, status, sector, sov, dac, dac5, dac5_desc, dac5_desc_detailed, contact_name, contact_email, sep="; "))
  # add parsed data into the main data frame
  data[nrow(data) + 1,] <- c(id, country, project, desc, commitment, approval_date, completion_date, duration, funding, status, sector, sov, dac, dac5, dac5_desc, dac5_desc_detailed, contact_name, contact_email)
  
  # calculate elapsed time for request
  elapsed <- Sys.time() - start
  # Respect the robots.txt - only do a request every 10 seconds
  printf("Download time: %.2f // Processing time: %.2fs // Sleep time: %.2fs\n", processing_time - start, elapsed - processing_time + start, 10 - elapsed)
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
closeAllConnections()
print("All done!")