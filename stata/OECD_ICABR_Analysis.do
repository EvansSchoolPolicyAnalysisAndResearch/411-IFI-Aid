/*
FILE: OECD_ICABR_Analysis.do
CREATED: May 17, 2022
MODIFIED: Sept 8, 2022
AUTHOR(S): Helen Ippolito
PURPOSE: Clean, analyze, and produce summary statistics of climate-related funding data from OECD for the ICABR conference July 2022.

Description of data files:
"CRDF-RP-2019.xlsx" -- OECD 2019 climate funding data (recipient perspective) downloaded from https://www.oecd.org/dac/financing-sustainable-development/development-finance-topics/climate-change.htm
*/

clear all 
set more off
capture log close

*Set working directory and log file
cd "\\netid.washington.edu\wfs\EvansEPAR\Project\EPAR\Working Files\411 - IFI Investment in SSA\2022 Project for ICABR\Stata"
*log using "IFI_ICABR.smcl", replace
global IFI_folder "\\netid.washington.edu\wfs\EvansEPAR\Project\EPAR\Working Files\411 - IFI Investment in SSA\2022 Project for ICABR\Stata"
global IFI_folder_out "\\netid.washington.edu\wfs\EvansEPAR\Project\EPAR\Working Files\411 - IFI Investment in SSA\2022 Project for ICABR\Stata\output_files"

* Sub-Saharan Africa country list
clear all 
import excel using "${IFI_folder}\input_data\ssa_countries.xlsx", firstrow 
save "${IFI_folder_out}\ssa_countries.dta", replace

* OECD funding data, recipient perspective
clear all
import excel using "${IFI_folder}\input_data\CRDF-RP-2019.xlsx", firstrow 
save "${IFI_folder_out}\oecd_recipient.dta", replace

gen provider_cat=.
replace provider_cat = 1 if inlist(ProviderType, "Multilateral development bank", "Other multilateral") // multilaterals
replace provider_cat = 2 if inlist(ProviderType, "DAC member", "Non-DAC member", "DAC Member") // bilaterals
replace provider_cat = 3 if ProviderType == "Private donor" // private donors
label define provider_cat_lab 1 "Multilateral" 2 "Bilateral" 3 "Private Donors"
label value provider_cat provider_cat_lab
tab provider_cat, mi

ren Y climate_commitusd_2019

* Multilat/bilateral funding breakdown (2019, Sub-Saharan Africa only)
preserve
merge m:1 Recipient using "${IFI_folder_out}\ssa_countries.dta", keep(1 3)
*tab SSA, mi
*tab Recipient if SSA==.
*br Recipient RecipientRegion SSA if SSA==. & RecipientRegion=="South of Sahara" // Djibouti, Saint Helena, Somalia, and Sudan are labeled by OECD with RecipientRegion=South of Sahara. These locs are not considered sub-Saharan in previous IFI work and will not be considered SSA here for consistency. -HI 5/17/22

* tab provider_cat, mi // at this point there are multiple rows per project - this is NOT the proportion of funding projects attributable to each funder type.
collapse (max) climate_commitusd_2019, by(DonorprojectN provider_cat ProjectTitle SSA)
tab SSA, mi
keep if SSA==1
*count // N = 3121
tab provider_cat, mi // proportion of funding projects attributable to each funder type

collapse (sum) climate_commitusd_2019, by(provider_cat)
global africa_clim_usd19_multilat = climate_commitusd_2019[1] // total climate funding to SSA from multilateral institutions
egen total_climate_commitusd_2019 = sum(climate_commitusd_2019)
global africa_climate_commitusd_2019 = total_climate_commitusd_2019[1] // total climate funding to SSA from all funding institutions
gen prop_climate_funding = climate_commitusd_2019/total_climate_commitusd_2019
save "${IFI_folder_out}\oecd_prop_climate_funding_africa_funder_type.dta", replace
restore


* Multilat/bilateral funding breakdown (2019, global)
preserve
collapse (max) climate_commitusd_2019, by(DonorprojectN provider_cat ProjectTitle)
tab provider_cat, mi // proportion of funding projects attributable to each funder type

collapse (sum) climate_commitusd_2019, by(provider_cat)
egen total_climate_commitusd_2019 = sum(climate_commitusd_2019)
gen prop_climate_funding = climate_commitusd_2019/total_climate_commitusd_2019
save "${IFI_folder_out}\oecd_prop_climate_funding_global_funder_type.dta", replace
restore


/*
* Multilat/bilateral funding breakdown (2019, Africa only)
preserve
keep if inlist(RecipientRegion, "Africa", "North of Sahara", "South of Sahara") // 108,391 obs dropped
* count // N = 6499
tab provider_cat, mi // at this point there are multiple rows per project - this is NOT the proportion of funding projects attributable to each funder type.
collapse (max) climate_commitusd_2019, by(DonorprojectN provider_cat ProjectTitle)
tab provider_cat, mi // proportion of funding projects attributable to each funder type

collapse (sum) climate_commitusd_2019, by(provider_cat)
global africa_clim_usd19_multilat = climate_commitusd_2019[1] // total climate funding to Africa from multilateral institutions
egen total_climate_commitusd_2019 = sum(climate_commitusd_2019)
global africa_climate_commitusd_2019 = total_climate_commitusd_2019[1]
gen prop_climate_funding = climate_commitusd_2019/total_climate_commitusd_2019
save "${IFI_folder_out}\oecd_prop_climate_funding_africa_funder_type.dta", replace
restore
*/


* Where do WB, IFAD, and AFDB rank in climate financing to sub-Saharan Africa in 2019?
preserve
merge m:1 Recipient using "${IFI_folder_out}\ssa_countries.dta", keep(1 3)
keep if SSA==1 // 12,562 obs dropped
collapse (max) climate_commitusd_2019, by(DonorprojectN Provider ProjectTitle provider_cat)
collapse (sum) climate_commitusd_2019, by(Provider provider_cat)
gen prop_climate_funding_africa = climate_commitusd_2019/$africa_climate_commitusd_2019
gsort -prop // WB and AfDB contribute greatest % of all climate-related funding to Africa (30% and 14%, respectively). IFAD contributes much less (1%).
save "${IFI_folder_out}\oecd_prop_climate_funding_africa_funder_org.dta", replace

keep if provider_cat==1 // multilaterals only
gen prop_multilat_climate_africa = climate_commitusd_2019/$africa_clim_usd19_multilat
gsort -prop_m // Among multilaterals, WB and AfDB contribute 58% and 27% of climate-related funding to Africa; IFAD contributes 2%. GCF contributes more than IFAD (6%). 
save "${IFI_folder_out}\oecd_prop_multilat_climate_funding_africa.dta", replace

/*
* Where do WB, IFAD, and AFDB rank in climate financing to Africa in 2019?
preserve
keep if inlist(RecipientRegion, "Africa", "North of Sahara", "South of Sahara") // 108,391 obs dropped
collapse (max) climate_commitusd_2019, by(DonorprojectN Provider ProjectTitle provider_cat)
collapse (sum) climate_commitusd_2019, by(Provider provider_cat)
gen prop_climate_funding_africa = climate_commitusd_2019/$africa_climate_commitusd_2019
gsort -prop // WB and AfDB contribute greatest % of all climate-related funding to Africa (27 and 14%, respectively). IFAD contributes much less (1%).
save "${IFI_folder_out}\oecd_prop_climate_funding_africa_funder_org.dta", replace

keep if provider_cat==1 // multilaterals only
gen prop_multilat_climate_africa = climate_commitusd_2019/$africa_clim_usd19_multilat
gsort -prop_m // Among multilaterals, WB and AfDB contribute 49% and 25% of climate-related funding to Africa; IFAD contributes 2%. EIB, EBRD, and GCF contribute more than IFAD. 
save "${IFI_folder_out}\oecd_prop_multilat_climate_funding_africa.dta", replace
*/





