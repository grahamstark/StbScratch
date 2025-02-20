#
# Start of a script to do ConJoint analysis using
# the `cjoint` package (https://cran.r-project.org/web/packages/cjoint/cjoint.pdf)
#
library( tidyverse)
library( cjoint )
library( forcats )

#
# This is the QUALTRICS dataset wrangled into the cjoint format
# using `energy-qualtrics-cjoint.jl` julia script.
# 
eng = read_delim("/mnt/data/ActNow/Energy/energy_data_for_cjoint.tab") |> tibble()
# cjoint likes factors
eng$Gender = as.factor(eng$Gender)
eng$Ethnic = as.factor(eng$Ethnic)
eng$Employment_Status = as.factor(eng$Employment_Status)
eng$Owner_Occupier = as.factor(eng$Owner_Occupier)
# eng$At_Risk_of_Destitution = as.factor(eng$At_Risk_of_Destitution)
eng$Managing_Financially = as.factor(eng$Managing_Financially)
eng$Satisfied_With_Income = as.factor(eng$Satisfied_With_Income)
eng$General_Health = as.factor(eng$General_Health)
eng$Has_Long_Term_Condition = as.factor(eng$Has_Long_Term_Condition)
eng$ADLS_Reduced = as.factor(eng$ADLS_Reduced)
eng$Sad_In_Last_Week = as.factor(eng$Sad_In_Last_Week)
eng$Anxious = as.factor(eng$Anxious)
eng$Voting_Attitude = as.factor(eng$Voting_Attitude)
eng$Vote_Last_Election = as.factor(eng$Vote_Last_Election)
eng$Vote_Next_Election = as.factor(eng$Vote_Next_Election)
eng$Politicians_All_The_Same = as.factor(eng$Politicians_All_The_Same)
eng$Politics_Force_For_Good = as.factor(eng$Politics_Force_For_Good)
eng$Party_In_Government_Doesnt_Matter = as.factor(eng$Party_In_Government_Doesnt_Matter)
eng$Politicians_Dont_Care = as.factor(eng$Politicians_Dont_Care)
eng$Politicians_Want_To_Make_Things_Better = as.factor(eng$Politicians_Want_To_Make_Things_Better)
eng$Shouldnt_Rely_On_Government = as.factor(eng$Shouldnt_Rely_On_Government)
eng$Ownership_Of_Energy_System = as.factor(eng$Ownership_Of_Energy_System)
eng$Onwership_Of_N_Sea_Oil = as.factor(eng$Onwership_Of_N_Sea_Oil)
eng$Transition_To_Net_Zero = as.factor(eng$Transition_To_Net_Zero)
eng$Energy_Price_Stability = as.factor(eng$Energy_Price_Stability)
eng$Funding_Options = as.factor(eng$Funding_Options)
eng$Energy_Independence = as.factor(eng$Energy_Independence)
eng$Job_Losses = as.factor(eng$Job_Losses)
eng$Energy_Poverty = as.factor(eng$Energy_Poverty)
eng$Avoidable_Deaths_From_Cold = as.factor(eng$Avoidable_Deaths_From_Cold)

eng$Destitution <- factor(eng$At_Risk_of_Destitution < 75, labels=c('At Risk (score >= 75)', "Not At Risk (Score < 75)"))
es <- as.numeric(eng$Employment_Status)
eng$Work_Status <- factor((es == 6)|(es == 7)|(es == 11), labels=c('Not In Work', 'In Work'))
glimpse( eng )
eng$Sex <- factor(eng$Gender != 'Male', labels=c('Male', 'Female/Non Binary'))
eng$EthnicGroup = factor(eng$Ethnic != '1. English, Welsh, Scottish, Northern Irish or British', labels=c('White British', 'Other Ethnic Group'))
eng$Last_Election = factor(eng$Vote_Last_Election == 'Labour Party', labels=c('Not Labour', 'Labour'))
eng$Low_On_Life_Ladder = factor(eng$Ladder < 5, labels=c('High on Ladder (5..10)', 'Low on Ladder (1..4)'))
eng$AgeBand = factor(eng$Age < 55, labels=c('Age 18-54', 'Age 55+'))

# trying to follow the example in the cjoint manual.
res1 <- amce( chosen_policy ~ 
    Gender + 
    Work_Status + 
    Ownership_Of_Energy_System + 
    Onwership_Of_N_Sea_Oil +
    Transition_To_Net_Zero +
    Energy_Price_Stability +
    Funding_Options +
    Energy_Independence +
    Job_Losses +
    Energy_Poverty +
    Avoidable_Deaths_From_Cold, 
    data=eng, respondent.id="CaseID" )

res2 <- amce( chosen_policy ~ 
    Sex +
    EthnicGroup + 
    Work_Status +
    Owner_Occupier +
    Destitution +
    AgeBand +
    Last_Election +
    Low_On_Life_Ladder +
    Ownership_Of_Energy_System + 
    Onwership_Of_N_Sea_Oil +
    Transition_To_Net_Zero +
    Energy_Price_Stability +
    Funding_Options +
    Energy_Independence +
    Job_Losses +
    Energy_Poverty +
    Avoidable_Deaths_From_Cold, 
    data=eng, respondent.id="CaseID" )

v2 = summary.amce(res2)
plot(res2)

#
# subsetting example
# Anna - This makes a subset of only Males
eng_subset <- subset(eng, Sex == 'Male')
# then just repeat the acmes and picture for this subset ..
# and then female .. Work_Status 

