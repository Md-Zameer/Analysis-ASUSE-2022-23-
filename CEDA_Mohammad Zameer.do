ssc install estout
ssc install ftools

*Merging and Assigning weightage 

cd "D:\ASUSE\Rawdata\DDI-IND-MOSPI-NSSO-ASUSE2122"

use "LEVEL - 12 (Block 10.1).dta", clear
cap gen wt= mult/100
cap gen ESID= fsu+ b1q3+ b1q4+ b1q5
save, replace
clear

use "LEVEL - 03 (Block 2.1, 2.2 & 2.3).dta",clear
cap gen wt= mlt/100
cap gen ESID= fsu+ b1q3+ b1q4+ b1q5
save, replace
clear

use "LEVEL - 02(Block 2).dta",clear
cap gen wt= Mult/100
cap gen ESID= fsu+ b1q3+ b1q4+ b1q5
save, replace
clear

use "LEVEL - 08 (Block 7).dta", clear
cap gen wt= mult/100
cap gen ESID= fsu+ b1q3+ b1q4+ b1q5
save, replace
clear

use "LEVEL - 09 (Block 8).dta", clear 
cap gen ESID= fsu+ b1q3+ b1q4+ b1q5
cap gen wt= mult/100
duplicates drop ESID, force
save "level_9.dta", replace
clear

* Merging 

use "LEVEL - 12 (Block 10.1).dta",clear
merge 1:1 ESID using "LEVEL - 02(Block 2).dta"
drop _merge
merge 1:1 ESID using "LEVEL - 03 (Block 2.1, 2.2 & 2.3).dta"
drop _merge
merge 1:1 ESID using "level_9.dta"
drop _merge
merge 1:m ESID using "LEVEL - 08 (Block 7).dta"


* Generating Variables 

*Female_owner as dummy 
gen female_owner = ( b2204 == "2")

* State Variable

gen StateCode = substr(nss_region, 1, 2)

tempfile blocks
save `blocks'

import excel "D:\ASUSE\NSS_ASUSE_21_22_Layout_mult_post (1).xlsx", sheet("State Code") cellrange(A2:B39) firstrow clear

merge 1:m StateCode using "`blocks'", nogen

save "inter_data.dta",replace


* State-wise proportion of female owned enterprise 
* Collapse at state level


collapse (mean) female_owner [aw=wt], by(StateName)

graph hbar (mean) female_owner, over(StateName, sort(1) descending label(labsize(vsmall))) ///
    blabel(bar, format(%4.2f) size(vsmall)) ///
    ytitle("Proportion of female-owned enterprises") 	note("Source: ASUSE 2021-22, weighted") 
	graph export "female_owned_ep_state.png", replace
	
* Sort and plot (Top 5 states)

*average proportion of female-owned enterprises by enterprise size for Enterprise size ranging from 1, 2, 3, 4….. upto 10 workers.
* First drop enterprises which shows the average number of worker >10.

use "inter_data",clear
su b8q9 

keep if inrange(b8q9 , 1, 10)
gen enterprise_size = b8q9

collapse (mean) female_owner [aw=wt], by(enterprise_size)


graph bar (mean) female_owner, over(enterprise_size, label(labsize(vsmall))) ///
    blabel(bar, format(%9.3f) size(vsmall)) ///
    ytitle("Proportion of female-owned enterprises") ///
	note("Source: ASUSE 2021-22, weighted") 
	
	graph export "female_owned_epsize.png", replace
	
		
*******************************************************************************




use "inter_data",clear

gen receipt1 = b7q3
replace receipt1 =. if inlist(b7q2, "762", "763", "764", "765", "766", "769", "771", "772")

gen expenses1 = b7q3
replace expenses1 =. if inlist(b7q2, "761", "763", "764", "765", "766", "769", "771", "772")

egen receipt = total(receipt1), by(ESID)
egen expenses = total(expenses1), by(ESID)

duplicates drop ESID,force

foreach var of varlist receipt expenses {
	replace `var' = `var'/30 if b2pt2265=="1" | b2pt2265=="2"
	replace `var' = `var'/365 if b2pt2265=="3"
	replace `var' = `var'*31
}

gen profit = receipt - expenses


ttest profit, by(female_owner)
estpost ttest profit, by(female_owner)
esttab using "ttest.tex", wide nonumber mtitle("Difference") se label replace 


destring b2207,replace
gen social_group = b2207 
lab var social_group "Social Group (Caste)"
lab define caste 1 "ST" 2 "SC" 3 "OBC" 4 "General" 9 "Not Known"
lab values social_group caste


estpost tabstat profit [aw=wt], by(social_group) stat(mean) 
eststo q2b
esttab q2b using "profit_by_caste.tex", cells("mean(fmt(2))") nostar booktabs replace

		***** Question 3*****
		*===================*
		
		
gen entry_year= b2215

keep if entry_year >= 2001 & entry_year <= 2021

gen treated_state = inlist(StateCode, "18", "10", "7", "29", "8", "3", "14")

generate treated = 1 if treated_state ==1
replace treated = 0 if treated ==.

gen post = entry_year >= 2015

gen policy = treated*post

ssc install reghdfe 

destring district,replace

eststo q3 :reghdfe female_owner policy [aw=wt], absorb(district entry_year) vce(cluster StateCode)

esttab q3 using "regression.tex", b(3) se replace ///
 label compress booktabs longtable stats(N r2) 


