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
library(tidyverse)
library(xml2)
library(magrittr)
library(rvest)

debug <- FALSE

base_url <- "https://projectsportal.afdb.org/dataportal/VProject/show/"
filename <- if(debug) "afdb-short.txt" else "afdb-ids.txt"
ouput_file <- if(debug) "../data/afdb-test.csv" else "../data/afdb-data.csv"


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
# grab the project ids from the file specified earlier in the file
proj_ids <- read_lines(filename, skip_empty_rows = TRUE)

# create a dataframe to hold the scraped data.
data <- data.frame(matrix(ncol = 5, nrow = 0))
names(data) <- c(
		"project.id", 
		"project.description", 
		"project.objective", 
		"date.completed", 
		"dac.code"
	)


# go through all of the ids listed in the file
for(id in proj_ids) {
	# get the time at the start of the loop to ensure not to dos the afdb site
	start <- Sys.time()
	# this print is mainly so i know things are still going and haven't stalled
	"scraping project" %>% paste(id, "\n" sep = " ") %>% cat()
	# clear things for the loop
	page  <- NULL
	count <- 0

	# using a loop to retry on failed attempts just in case there is an http
	# request error. only retry 20 times in case there is a bad id that doesn't
	# work (it happened, don't remove the loop limiter)
	while(length(page) == 0 && count < 20){
		# download the webpage
		page <- get_html(paste(base_url, id, sep=""))
		count <- count + 1
	}
	# if the loop ended because of the loop limiter just go on to the next id
	if(length(page) == 0) next

	##############################
	# parse the web page results #
	##############################

	# turn the main table into a data frame and pull out the rows with the info
	# we care about (projected completion date and dac sector code)
	date <- (page %>% 
		html_node(".table") %>%
		html_table(header = FALSE) %>%
		filter(X1 == "Planned Completion Date"))
	dac <- (page %>% 
		html_node(".table") %>%
		html_table(header = FALSE) %>%
		filter(X1 == "DAC Sector Code"))

	# check to see if we got anything, if not replaced with n/a
	date <- if(nrow(date) == 0) "N/A" else date[['X2']]
	dac <- if(nrow(dac) == 0) "N/A" else dac[['X2']]

	# by default set to n/a will replace later if we find what we're after
	desc <- "N/A"
	obj <- "N/A"
	# pull out all the divs and put them in a vector like object
	divs <- page %>% html_nodes("div")

	# iterate through the list looking for the general description and the
	# objectives
	for(div in divs) {
		if(html_text(html_node(div,"h3")) %in% "Project General Description"){
			desc <- div %>% html_node("p") %>% html_text()
		}
		if(html_text(html_node(div,"h3")) %in% "Project Objectives") {
			obj <- div %>% html_node("p") %>% html_text()
		}
	}
	# when debugging it can be useful to have this information. left out obj and
	# desc because they are so long it makes the other information hard to see.	
	if(debug) print(paste(id, date, dac, sep="; "))

	# add parsed data into the main data frame
	data[nrow(data) + 1,] <- c(id, desc, obj, date, dac)

	# calculate elapsed time for request
	elapsed <- Sys.time() - start
	# Respect the robots.txt - only do a request every 10 seconds
	if(elapsed < 10) {
		Sys.sleep(10-elapsed)
	}
}
# similar to the http requests, handle errors on for writing to disk.
written <- FALSE
count <- 0
# once again a loop with 20 retries, this time for writing to disk.
while(!written && count < 20){
	written <- write_file(data, ouput_file)
	count <- count + 1
}
