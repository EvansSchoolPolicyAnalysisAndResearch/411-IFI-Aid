/*
FILE: IFI_ICABR_Analysis.do
CREATED: April-May 2022
MODIFIED: Sept 8, 2022
AUTHOR(S): Kelsey Figone, Helen Ippolito, Basil Hariri
PURPOSE: Clean, analyze, and produce summary statistics of climate-related and ag-related funding from IFIs (World Bank, AfDB, and IFAD) for the ICABR conference July 2022. 

General note: we are not including bilaterals and other flows as there is no easy way to categorize such flows as being "climate-related" with existing data. 

Description of data files:
"ifi_data.xlsx" -- Output of a python webscraping script by Basil Hariri, including project-level data from three bank project databases. 
"cpi_data.xlsx" -- US Consumer Price Index data for Jan 1913-March 2022 downloaded from US Bureau of Labor Statistics: data.bls.gov
"CRI_data.xlsx" -- Climate Risk Index data by country downloaded from germanwatch.org

Table of Contents
*****************
0. Setup
0.1 Exploring
I. Data Cleaning
II. Analysis and Results
II.1 Distribution of projects/funding between climate/ag/onfarm/others and IFIs
II.2 Research Question 1: What proportion of agriculture-related lending across the three multilaterals of interest has a climate component?
II.3 Research Question 2: Which countries are borrowing most for climate-related agricultural projects? Is the amount of borrowing correlated with a country’s climate risk?
*/


********************************************************************************
// 0. SETUP
clear all 
set more off
capture log close

*Set working directory and log file
cd "\\netid.washington.edu\wfs\EvansEPAR\Project\EPAR\Working Files\411 - IFI Investment in SSA\2022 Project for ICABR\Stata"
*log using "IFI_ICABR.smcl", replace
global IFI_folder "\\netid.washington.edu\wfs\EvansEPAR\Project\EPAR\Working Files\411 - IFI Investment in SSA\2022 Project for ICABR\Stata"
global IFI_folder_out "\\netid.washington.edu\wfs\EvansEPAR\Project\EPAR\Working Files\411 - IFI Investment in SSA\2022 Project for ICABR\Stata\output_files"

*CPI data
clear all
import excel using "${IFI_folder}\input_data\cpi_data.xlsx", firstrow
egen annual_calc = rowmean(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) 
replace Annual = annual_calc if Annual==.
keep Year Annual
ren Annual cpi_annual
ren Year year
save "${IFI_folder_out}\cpi.dta", replace

gen cpi19 = cpi_annual if year==2019
egen cpi_2019 = max(cpi19)
global cpi_2019 = cpi_2019[1] // this is a very convoluted way to get the 2019 annual CPI - please feel free to replace if you know a more efficient way.
* di "$cpi_2019"

*Climate Risk Index data
clear all
import excel using "${IFI_folder}\input_data\CRI_data.xlsx", firstrow // small ranking, small CRI score == most climate risk
ren Country country
save "${IFI_folder_out}\cri.dta", replace

*IFI project data
clear all
import excel using "${IFI_folder}\input_data\ifi_data.xlsx", firstrow

rename (A IFI Country ProjectID ProjectTitle Status ApprovalDate PrimarySector CommitmentAmountUSD ProjectDuration ClosingDate ProjectContact ContactDetails Description AdditionalSectors ClimateFlag OnFarmFlag RuralAgEconomiesFlag) (number ifi country id title status appdate sector commitmentusd duration closingdate contact_name contact_details description moresectors climate onfarm ruralag)

order id ifi country title description commitmentusd sector moresectors appdate closingdate duration climate onfarm ruralag

save "${IFI_folder_out}\ifi_icabr.dta", replace


********************************************************************************
// 0.1 Data exploration
/*
tab country // Data includes regional projects (Eastern Africa, Western Africa, etc.). One project tagged country='world'
return list

//isid title // Title does not uniquely identify. 
isid id // Id uniquely identifies projects, so that must mean that two banks have collaborated on a project, or two countries, but they're considered separate projects with cumulative funding. Makes sense to consider them separately since each bank is contributing distinct funds

duplicates report title
duplicates list title
duplicates tag title, gen(dup_title)
tab dup_title, missing

tab title ifi if dup_title > 0 // Some are shared between two banks, but most are not.
browse if dup_title > 0

codebook commitmentusd
tab title if commitmentusd == 0 // We have 10 projects lacking a commitment amount. All are WB projects, some are older (appdates between 1991-2011).
tab status if commitmentusd == 0 // 8 projects lacking commitment amount are marked as Active. 

tab sector, missing // 355 missing sectors. 
tab moresectors, missing // 535 missing here.
br if strpos(moresectors, "Workforce Development and Vocational") // Some of the "duplicate" moresectors values are actually different if you look at the entire entry 

codebook appdate // Needs to be converted to %td format.
codebook closingdate // Needs to be converted to %td format.
codebook duration // Range includes negative values. 
tab appdate if duration < 0
tab title status if duration <0 // Only one project has a negative duration: AfDB project (P-TD-FA0-007) - closing date precedes the appdate.
tab status
tab status
*/


********************************************************************************
// I. DATA CLEANING

*** appdate and closingdate cleaning
*** Purpose: Get appdate and closingdate into %td format and remove observations that lack sufficient date information to determine inflation-adjusted annualized commitment amounts. 

*appdate
gen double appdate_td = clock(appdate, "DMYhms")
browse if appdate_td == .
codebook appdate if appdate_td == .
replace appdate_td = clock(appdate, "YMD") if appdate_td == .
codebook appdate if appdate_td == .
replace appdate_td = clock(appdate, "DMY") if appdate_td == .
codebook appdate if appdate_td == . // Only missing values left.

summ appdate_td, detail
tab ifi if appdate == "" // All WB
tab status if appdate == "" // All "Pipeline"
tab sector if appdate == "", missing  // All of these 323 projects lack approval dates, 308 lack closing dates as well.  297 of 323 lack sector data, primarily because these are all Pipeline World Bank projects and are very tentative. Decision to drop the projects missing sector information, since this is the only way to categorize the ag projects (they were not identified via a keyword search in Python as the climate projects were; rather they were categorized as "Rural/Ag" or "On Farm" on the basis of sectors alone). 
codebook id if climate == 1 & sector == "" // Projects without sectors include 46 projects that had been flagged as climate-related. 
drop if sector == "" // N = 2121 obs at this point in code. 

format appdate_td %tc
replace appdate_td = dofc(appdate_td)
format appdate_td %td
codebook appdate_td

drop appdate 
rename appdate_td appdate
label var appdate "Approval Date"

*closingdate 
gen double closingdate_td = clock(closingdate, "DMYhms")
replace closingdate_td = clock(closingdate, "YMD") if closingdate_td == .
replace closingdate_td = clock(closingdate, "DMY") if closingdate_td == .
codebook closingdate
codebook closingdate_td
browse if closingdate_td == .
replace closingdate_td = clock(closingdate, "Y") if closingdate_td == .

codebook appdate if closingdate_td == .
tab ifi if closingdate_td == .
format closingdate_td %tc
replace closingdate_td = dofc(closingdate_td)
format closingdate_td %td
codebook closingdate_td // Dates with 1Jan are assumed to be dates imputed from year-only observations (no day/month reported). 
*Note that 19 projects were categorized as closingdate="2022" and thus transformed to "1jan2022". Since there are no other projects that were originally closing on Jan 1, 2022, then we can presume all of the "1jan2022" dates are the ones that were initially reported as closing in "2022" and should not be dropped later in this process. 

drop closingdate 
rename closingdate_td closingdate 
label var closingdate "Closing Date"

keep if appdate!=. | closingdate!=. // Dropping projects with either no app date or no closing date, N = 11. Projects with only one of these missing are retained. 


*** Impute average duration
*** Purpose: Some projects lack either appdate or closing date. Use averages from other ifi-specific projects to impute the durations for these projects; this later allows us to annualize the full commitment amount over the lifetime of the project. We DON'T want to impute by country across IFIs because IFIs have different funding priorities which translates into different implementation lengths; IFAD, for example, tends to fund longer-term projects (5+ years). 

codebook duration
replace closingdate = td(31dec2021) if id == "P-TD-FA0-007" // Documents accessible on this project's webpage suggest that this project has a planned implementation period of 3 years, through 2021. https://projectsportal.afdb.org/dataportal/VProject/show/P-TD-FA0-007
replace duration = year(closingdate)-year(appdate) if id == "P-TD-FA0-007"
codebook duration

*Drop projects with outlying project durations. 
codebook duration
tab duration, sort
browse if duration <1 // N=18, none of these are pipeline, their approval dates are fairly recent. Seem legitimate and have data filled in.
browse if duration >20 & duration != . // N=3
tab id if duration >50 & duration !=. // N=1, Planned completion date of this project really is 2065: https://projectsportal.afdb.org/dataportal/VProject/show/P-Z1-K00-077
*Ultimately did not need to drop any projects based on duration.

*Generate file with average project durations for each country-IFI combination in dataset. 
preserve
collapse (mean) duration, by(country ifi)
ren duration mean_country_ifi_duration
save "${IFI_folder_out}\mean_country_ifi_duration.dta", replace
restore

*Generate file with average project durations for each IFI
preserve
collapse (mean) duration, by(ifi)
ren duration mean_ifi_duration
save "${IFI_folder_out}\mean_ifi_duration.dta", replace
restore

*Inpute durations based on country-IFI mean durations and IFI mean durations
merge m:1 country ifi using "${IFI_folder_out}\mean_country_ifi_duration.dta"
count if missing(duration) // 870 projects don't have country-IFI imputation values. Need to impute with IFI medians - 537 projects don't have duration data.
gen duration_imputed = duration
replace duration_imputed = mean_country_ifi_duration if duration_imputed ==. // 535 replacements (2 missing)
drop _merge
merge m:1 ifi using "${IFI_folder_out}\mean_ifi_duration.dta"
replace duration_imputed = mean_ifi_duration if duration_imputed ==. // 2 real changes made
count if missing(duration_imputed) // returns 0
drop _merge mean*

*Estimate appdate for projects with closingdate and imputed duration but missing appdates
gen appdate_imp = appdate
replace appdate_imp = closingdate - (duration_imp*365.25) if appdate_imp == .
format appdate_imp %td
tab appdate_imp, missing
// duration_imp and appdate_imp contain original values where available + imputed values. Duration, appdate, and closingdate ONLY contain original raw data.

*Impute completion date, drop completed projects remaining in dataset
gen closingdate_imp = closingdate
replace closingdate_imp = appdate_imp + (duration_imp*365.25) if closingdate_imp == . // closingdate_imp is calculated based off imputed and raw duration vals in duration_imp. Can look at duration and appdate to see raw values - obs missing these vals are imputed. 
format closingdate_imp %td
count if closingdate_imp==. // N=0
count if closingdate_imp < td(04may2022) // N=280
count if closingdate_imp == td(01jan2022) // N=19
drop if closingdate_imp < date("04052022","DMY") & closingdate_imp != date("01012022", "DMY") // 19 obs from Jan 1 (imputed in initial data cleaning) should be kept. Unsure when they actually end in 2022, so considering them active as of May 4, 2022. 280 projects with closingdate_imp before May 4, 2022 -> 261 obs deleted = 280-19.  

*Adjusting full grant amount to 2019 USD (inflation only, not discounting) for discussion alongside OECD data; their values and most current data are for 2019 USD. 
gen year = year(appdate_imp)
merge m:1 year using "${IFI_folder_out}\cpi.dta", keep(1 3)
drop _merge
gen commitmentusd_2019 = commitmentusd*($cpi_2019/cpi_annual)
order commitmentusd, before(commitmentusd_2019)
count if commitmentusd==0 //3 projects
drop if commitmentusd==0

*Annualized funding
gen commitmentusd_2019_annualized = commitmentusd_2019/duration_imp

count // N = 1846 projects

*Label values of IFI variable
tab ifi, missing nol
gen ifi2 = .
replace ifi2 = 1 if ifi == "World Bank"
replace ifi2 = 2 if ifi == "African Development Bank"
replace ifi2 = 3 if ifi == "International Fund for Agricultural Development"
tab ifi2, missing
label define ifi_lbl 1 "World Bank" 2 "African Development Bank" 3 "IFAD"
label value ifi2 ifi_lbl
label var ifi2 "IFI"
drop ifi
rename ifi2 ifi 

*Manual changes to country names
replace country="Cabo Verde" if country == "Verde" // One project tagged to "verde" - assuming this is Cabo Verde. 

*Save cleaned and imputed project data
save "${IFI_folder_out}\clean_project_data.dta", replace


********************************************************************************
// II. ANALYSIS & RESULTS

// II.1 Distribution of projects/funding between climate/ag/onfarm/others and IFIs. 
*What proportion of projects and funding are tagged to each climate/ag tag?
tab climate
tab ruralag
tab onfarm

table climate, c(sum commitmentusd_2019_annualized)
table ruralag, c(sum commitmentusd_2019_annualized)
table onfarm, c(sum commitmentusd_2019_annualized)

*What proportion of projects come from each bank?
tab ifi 

*What proportion of projects are ruralag-related?
tab ifi ruralag, cell // proportion of projects in each IFI and ruralag/non-ruralag category (%s add to 100 for all banks in aggregate)
tab ifi ruralag, row // proportion of projects within each IFI devoted to ruralag

*What proportion of projects are onfarm-related?
tab ifi onfarm, cell
tab ifi onfarm, row

*What proportion of projects are climate-related?
tab ifi climate, cell
tab ifi climate, row
tab ruralag climate, cell //Only 4.8% are both.
tab onfarm climate, cell //Only 4.3% are both.


// II.2 Research Question 1: What proportion of agriculture-related lending across the three multilaterals of interest has a climate component?

*Climate-ruralag projects / total ag projects by IFI; climate-onfarm projects / total onfarm projects by IFI
preserve
keep if ruralag==1
tab ifi climate, row
restore

preserve
keep if onfarm==1
tab ifi climate, row
restore

*Climate-ruralag projects / total climate projects by IFI; climate-onfarm projects / total climate projects by IFI
preserve
keep if climate==1
tab ifi ruralag, row
restore

preserve 
keep if climate==1
tab ifi onfarm, row
restore

*What proportion of lending for rural-ag projects goes toward climate, by IFI?
preserve
keep if ruralag==1
collapse (sum) commitmentusd_2019_annualized, by(ifi)
rename commitmentusd_2019_annualized commit_ruralag_2019_an
save "${IFI_folder_out}\ifi_ag_spending.dta", replace
restore

preserve 
keep if ruralag==1 & climate==1
collapse (sum) commitmentusd_2019_annualized, by(ifi)
rename commitmentusd_2019_annualized commit_clim_ag_2019_an
merge 1:1 ifi using "${IFI_folder_out}\ifi_ag_spending.dta"
gen prop_clim_ag_ifi_an = commit_clim_ag_2019_an/commit_ruralag_2019_an
drop _merge
save "${IFI_folder_out}\proportion_clim_ag_spending_ifi.dta", replace
restore

*What proportion of lending for onfarm projects goes toward climate, by IFI?
preserve
keep if onfarm==1
collapse (sum) commitmentusd_2019_annualized, by(ifi)
rename commitmentusd_2019_annualized commit_onfarm_2019_an
save "${IFI_folder_out}\ifi_onfarm_spending.dta", replace
restore

preserve 
keep if onfarm==1 & climate==1
collapse (sum) commitmentusd_2019_annualized, by(ifi)
rename commitmentusd_2019_annualized commit_clim_onfarm_2019_an
merge 1:1 ifi using "${IFI_folder_out}\ifi_onfarm_spending.dta"
gen prop_clim_onfarm_ifi_an = commit_clim_onfarm_2019_an/commit_onfarm_2019_an
drop _merge
save "${IFI_folder_out}\proportion_clim_onfarm_spending_ifi.dta", replace
restore

*What proportion of lending for climate projects goes toward ruralag, by IFI?
preserve
keep if climate==1
collapse (sum) commitmentusd_2019_annualized, by(ifi)
rename commitmentusd_2019_annualized commit_climate_2019_an
save "${IFI_folder_out}\ifi_climate_spending.dta", replace
restore

preserve 
keep if ruralag==1 & climate==1
collapse (sum) commitmentusd_2019_annualized, by(ifi)
rename commitmentusd_2019_annualized commit_clim_ag_2019_an
merge 1:1 ifi using "${IFI_folder_out}\ifi_climate_spending.dta"
gen prop_ag_clim_ifi_an = commit_clim_ag_2019_an/commit_climate_2019_an
drop _merge
save "${IFI_folder_out}\proportion_ag_clim_spending_ifi.dta", replace
restore

*What proportion of lending for climate projects goes toward onfarm, by IFI?
preserve 
keep if onfarm==1 & climate==1
collapse (sum) commitmentusd_2019_annualized, by(ifi)
rename commitmentusd_2019_annualized commit_clim_onfarm_2019_an
merge 1:1 ifi using "${IFI_folder_out}\ifi_climate_spending.dta"
gen prop_onfarm_clim_ifi_an = commit_clim_onfarm_2019_an/commit_climate_2019_an
drop _merge
save "${IFI_folder_out}\proportion_onfarm_clim_spending_ifi.dta", replace
restore


// II.3 Research Question 2: Which countries are borrowing the most for climate-related agricultural projects? Is the amount of borrowing correlated with a country's climate risk?

*Which countries borrow the most for climate-ag related projects?
preserve
keep if climate==1 & ruralag==1
collapse (sum) commitmentusd_2019_annualized, by(country) // generates total project spending on rural/ag climate
ren commitmentusd_2019_annualized country_climate_ag_spending_an
gsort -country_climate_ag_spending_an
save "${IFI_folder_out}\country_climate_ag_spending.dta", replace
restore

*Which countries borrow the most for on-farm related projects? 
preserve
keep if climate==1 & onfarm==1 // Using the ruralag flag here to be inclusive of all the agriculture projects we want to subset for climate spending.
collapse (sum) commitmentusd_2019_annualized, by(country) // generates total annualized project spending on onfarm climate
ren commitmentusd_2019_annualized country_climate_onf_spending_an
gsort -country_climate_onf_spending_an
save "${IFI_folder_out}\country_climate_onfarm_spending.dta", replace
restore

*Which countries have the highest proportion of borrowing for climate+ruralag related projects relative to all ruralag borrowing? 
preserve
keep if ruralag==1
collapse (sum) commitmentusd_2019_annualized, by(country)
ren commitmentusd_2019_annualized country_total_ag_an
merge 1:1 country using "${IFI_folder_out}\country_climate_ag_spending.dta"
replace country_climate_ag_spending_an=0 if country_climate_ag_spending_an==.
gen proportion_climate_ag_an = country_climate_ag_spending_an/country_total_ag_an
drop _merge
merge 1:1 country using "${IFI_folder_out}\cri.dta", keep (1 3)
drop _merge

*Is there a relationship between CRI and proportion of annualized ruralag spending focused on climate?
reg proportion_climate_ag_an CRIScore0019 // no statistically significant relationship
correlate CRIScore0019 proportion_climate_ag_an
scatter proportion_climate_ag_an CRIScore0019
graph export "${IFI_folder}\prop_clim_ag_an_CRI.jpg", replace

gsort -proportion_climate_ag_an
save "${IFI_folder_out}\proportion_climate_ag_spending.dta", replace
restore

*Which countries have the highest proportion of borrowing for climate+on farm related projects relative to all onfarm borrowing? 
preserve
keep if onfarm==1
collapse (sum) commitmentusd_2019_annualized, by(country)
ren commitmentusd_2019_annualized country_total_onfarm_an
merge 1:1 country using "${IFI_folder_out}\country_climate_onfarm_spending.dta"
replace country_climate_onf_spending_an=0 if country_climate_onf_spending_an==.
gen proportion_climate_onfarm_an = country_climate_onf_spending_an/country_total_onfarm_an
drop _merge
merge 1:1 country using "${IFI_folder_out}\cri.dta", keep (1 3)
drop _merge

*Is there a relationship between CRI and proportion of annualized on farm spending focused on climate?
reg proportion_climate_onfarm_an CRIScore0019 // no statistically significant relationship
scatter proportion_climate_onfarm_an CRIScore0019
//graph export "${IFI_folder}\prop_clim_ag_an_CRI.jpg", replace

gsort -proportion_climate_onfarm_an
save "${IFI_folder_out}\proportion_climate_onfarm_spending.dta", replace
restore


