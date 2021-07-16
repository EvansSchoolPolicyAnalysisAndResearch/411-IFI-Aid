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
#install.packages("tidyverse")
#install.packages("xml2")
#install.packages("magrittr")
#install.packages("rvest")
#install.packages("sjmisc")
library(tidyverse)
library(xml2)
library(magrittr)
library(rvest)
library(sjmisc)

debug <- TRUE

base_url <- "https://projectsportal.afdb.org/dataportal/VProject/show/"
filename <- if(debug) "afdb-short.txt" else "afdb-ids.txt"
output_file <- if(debug) "../data/afdb-test.csv" else "../data/afdb-data.csv"

# From what i can tell this is the best way to prevent the whole system from 
# crashing on a network glitch.
get_html <- function(url) {
  tryCatch(
    read_html(url),
    error = function(e) {
      cat("request failed, retrying.\n")
      Sys.sleep(5) 
      NULL
    }
  )
}

# a little bit of insurance against losing 13 hours of scraping by catching 
# errors related to writing to disk. it happened. for the love of god don't 
# try to go without error handling when the task takes 13 hours to run.
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

main_table_parse <- function(page, x1) {
  temp <- (page %>% 
    html_node(".table") %>%
    html_table(header = FALSE) %>%
    filter(X1 == x1))
  # check if table had requested data, if not replaced with "N/A"
  return (if(nrow(temp) == 0) "N/A" else temp[['X2']])
}

#Searches every table in the html page for x1
all_table_parse <- function(page, x1) {
  ret <- ""
  tables <- (page %>% html_nodes("table"))
  for(i in 1:length(tables)){
    if(is.null(tables[[i]])){
      next
    }
    table <- tables %>% .[[i]] %>% 
             html_table(header = FALSE, trim=TRUE)
    #Check if the current table has terrible whitespace in the way the funding table does. 
    if(str_contains(table[['X1']], "\n\t") && !str_contains(table[['X1']], "Download")){
      #Reconstruct in the way it should be then filter
      table_str <- str_replace_all(table[['X1']], "[^\\S ]+[ ]+[^\\S ]+", "***")
      #cat("TABLE_POST:")
      #print(table_str)
      table_list <- strsplit(table_str, "\\*\\*\\*")
      if(is.null(table_list) || length(table_list) == 0){
        print("TABLE_LIST IS NULL")
      } else {      
        print(paste("TABLE_LIST IS", table_list)) 
        for(j in 1:length(table_list)){
          if(table_list[[j]][[1]] == x1){
            ret <- paste(ret, table_list[[j]][[2]], sep = ", ")
          }  
        }
      }
    }
  }
  
  ret <- substring(ret, first = 3)
  #print(paste("RETURNING:", ret))
  return(ret)
}

# grab the project ids from the file specified earlier in the file
proj_ids <- read_lines(filename, skip_empty_rows = TRUE)

# create a dataframe to hold the scraped data.
data <- data.frame(matrix(ncol = 15, nrow = 0))
names(data) <- c(
  "Project Code",
  "Country",
  "Project Title",
  "Objective",    
  "Description",  
  "Commitment in U.A.",
  "Status",
  "Start Date",
  "Completion Date",
  "Project Duration",
  "Source of Financing",
  "Sector",
  "DAC Sector Code",
  "DAC5 Code",
                  #"DAC5 Description",
  "Sovereign"
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
    page <- get_html(paste(base_url, id, sep=""))
    count <- count + 1
  }
  # if the loop ended because of the loop limiter skip to next id
  if(length(page) == 0) next

  ##############################
  # parse the web page results #
  ##############################
  # pull info from main web page table
  funding <- all_table_parse(page, "Funding")
  
  commitment <- main_table_parse(page, "Commitment")
  commitment <- if (str_length(commitment) > 5) substring(commitment, 5) else commitment
  status <- main_table_parse(page, "Status")
  approval_date <- main_table_parse(page, "Approval Date")
  completion_date <- main_table_parse(page, "Planned Completion Date")
  duration <- round(difftime(as.Date(completion_date, format="%d %b %Y"),
                             as.Date(approval_date, format="%d %b %Y"),
                             units="days")
                    / 365.25, 2)
  sector <- main_table_parse(page, "Sector")
  dac <- main_table_parse(page, "DAC Sector Code")
  dac5 = substring(dac, 1,3)
  sov <- main_table_parse(page, "Sovereign / Non-Sovereign")
  #print(paste("funding: ", funding))
  
  #Get country & project names
  country_plus_project <- str_split(page %>% html_node("h2") %>% html_text2(), " - ")[[1]]
  country <- if(is.na(country_plus_project[1])) "N/A" else country_plus_project[1]
  project <- if(is.na(country_plus_project[2])) "N/A" else country_plus_project[2]
  
  # by default set to n/a will replace later if we find what we're after
  desc <- "N/A"
  obj <- "N/A"
  # pull out all the divs and put them in a vector like object
  divs <- page %>% html_nodes("div")
  # iterate through the list looking for information
  for(div in divs) {
    if(html_text(html_node(div,"h3")) %in% "Project General Description"){
      desc <- div %>% html_node("p") %>% html_text()
    }
    if(html_text(html_node(div,"h3")) %in% "Project Objectives") {
      obj <- div %>% html_node("p") %>% html_text()
    }
  }
	
  if(debug) print(paste(id, country, project, commitment, status, approval_date, completion_date, duration, funding, sector, dac, dac5, sov, sep="; "))
  
  # add parsed data into the main data frame
  data[nrow(data) + 1,] <- c(id, country, project, obj, desc, commitment, status, approval_date, completion_date, duration, funding, sector, dac, dac5, sov)
  
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
	written <- write_file(data, output_file)
	count <- count + 1
}

print("All done!")