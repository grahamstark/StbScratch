include( "scripts/qualtrix_libs.jl")
# make edited qualtrics file
tran, tran_edit = new_transport_conjoint()
# 1st obs in each group in edited file
tranb = tran_edit[(tran_edit.profile.==1) .& (tran_edit.contest_no .==1),:]

energy, ener_edit = new_energy_conjoint()
enerb = ener_edit[(ener_edit.profile.==1) .& (ener_edit.contest_no .==1),:]

function do_transforms!( dall :: DataFrame )

    dall = dall[(.! ismissing.(dall.HH_Net_Income_PA )) .& (dall.HH_Net_Income_PA .> 0),:]
    n = size(dall)[1]
    dall.HH_Net_Income_PA .= ActNow.recode_income.( dall.HH_Net_Income_PA)
    dall.log_income = log.(dall.HH_Net_Income_PA)
    
    dall.last_election = ActNow.recode_party.( dall.Vote_Last_Election, condensed=false )
    dall.last_election_condensed = ActNow.recode_party.( dall.Vote_Last_Election, condensed=true  )
    dall.next_election =  ActNow.recode_party.( dall.Vote_Next_Election, condensed=false )
    dall.next_election_condensed .= ActNow.recode_party.( dall.Vote_Next_Election, condensed=true )
    
    tranb.employment_2 = ActNow.recode_employment.( tranb.Employment_Status)
 
    dall.age_sq = dall.Age .^2
    # dall.Gender = ActNow.recode_gender.( dall.Gender )
    dall.trust_in_politics = ActNow.build_trust.( eachrow( dall ))
    # dall.Owner_Occupier= convert.(String,dall.Owner_Occupier)
    # tranb.General_Health= convert.(String,tranb.General_Health)    
end

tranb.Gender = recode_gender( tranb.Gender )
tranb.Employment_Status = recode_employment.( tranb.Employment_Status )
tranb.Owner_Occupier = yn.( tranb.Owner_Occupier )
tranb.Managing_Financially = fm.( tranb.Managing_Financially )
tranb.General_Health = goodbad.(tranb.General_Health)
tranb.Satisfied_With_Income = satisfied.(tranb.Satisfied_With_Income)
tranb.General_Health = goodbad.( tranb.General_Health )
tranb.Has_Long_Term_Condition = yn.(tranb.Has_Long_Term_Condition )
tranb.ADLS_Reduced = adls.(tranb.ADLS_Reduced)
tranb.Sad_In_Last_Week = sad.(tranb.Sad_In_Last_Week)
tranb.Anxious = sad.( tranb.Anxious )
tranb.Voting_Attitude = elvote.(tranb.Voting_Attitude)
tranb.Vote_Last_Election = polparty.(tranb.Vote_Last_Election)
tranb.Vote_Next_Election = mayor.(tranb.Vote_Next_Election)
tranb.Politicians_All_The_Same = agdis.(tranb.Politicians_All_The_Same)
tranb.Politics_Force_For_Good = agdis.(tranb.Politics_Force_For_Good)
tranb.Party_In_Government_Doesnt_Matter = agdis.(tranb.Party_In_Government_Doesnt_Matter)
tranb.Politicians_Dont_Care = agdis.(tranb.Politicians_Dont_Care)
tranb.Politicians_Want_To_Make_Things_Better = agdis.(tranb.Politicians_Want_To_Make_Things_Better)
tranb.Shouldnt_Rely_On_Government = agdis.(tranb.Shouldnt_Rely_On_Government)
tranb.Vote_Last_Election = ActNow.recode_party( tranb.Vote_Last_Election; condensed=false )
tranb.ethnic_2 = recode_ethnic.( tranb.Ethnic )
do_transforms!( tranb )

enerb.ethnic_2 = ActNow.recode_ethnic.( enerb.Ethnic )
do_transforms!( enerb )

