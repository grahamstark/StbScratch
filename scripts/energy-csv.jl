#
# This script converts the Qualtrics Energy conjoint data into something
# that cjoint package can use, with one choice set per row and 
# nicer labels. Choice sets are paired. Kinda sorta wide-to-long.
# 
using DataFrames, CSV, PrettyTables, OrderedCollections 

"""
Crude version of Tidyverse `glimpse` command - print 1st `n` rows of each
col in a DataFrame, sideways.
"""
function glimpse( d::AbstractDataFrame; n = 10 )
   n = min(n, size(d)[1])
   w=permutedims(d)[:,1:n]
   pretty_table(insertcols( w, 1 ,:name=>names(d)))
end

# tab converted and edited version of 'Energy Act Now Conjoint_12 February 2024_12.32_choice_text.xlsx'
qualtrics = CSV.File("/mnt/data/ActNow/Energy/conjoint.tab")|>DataFrame

n = 100_000 # reserve many more output rows than we'll ever actually need
# output dataframe
cjoint_data = DataFrame(
    ResponseId = fill( "", n ), # from the survey
    CaseID = fill(0, n ), # int person id needed by cjoint
    contest_no = fill( 0, n),
    # -- demographic fields renamed from the Conjoint survey
    Age = fill(0,n),
    Gender = fill("",n),
    Ethnic = fill("",n),
    Postcode = fill("",n),
    HH_Net_Income_PA = fill(0.0,n),
    Employment_Status = fill("",n),
    Owner_Occupier = fill("",n), # convert later
    At_Risk_of_Destitution = fill(0,n),
    Managing_Financially = fill("",n),
    Satisfied_With_Income = fill("",n),
    Ladder = fill(0,n),
    General_Health = fill("",n),
    Has_Long_Term_Condition = fill("",n),
    ADLS_Reduced = Array{Union{Missing,String}}(undef,n),
    Sad_In_Last_Week = fill("",n),
    Anxious = fill("",n),
    Left_Right = fill(0,n),
    Voting_Attitude = fill("",n),
    Vote_Last_Election = fill("",n),
    Vote_Next_Election = fill("",n),
    Politicians_All_The_Same = fill("",n),
    Politics_Force_For_Good = fill("",n),
    Party_In_Government_Doesnt_Matter = fill("",n),
    Politicians_Dont_Care = fill("",n),
    Politicians_Want_To_Make_Things_Better = fill("",n),
    Shouldnt_Rely_On_Government = fill("",n ), #Array{Union{Missing,String}}(undef,n),

    # the studd cjoint needs, rearranged from Conjoint survey
    profile = fill(0,n), # which profile this row represents (1 or 2 in our case, could in principle be > 2)
    chosen_policy = fill(0,n), # this is 0 or 1, not 1 or 2
    Ownership_Of_Energy_System = fill("",n), # these wull need converting to factors in R
    Onwership_Of_N_Sea_Oil = fill("",n),
    Transition_To_Net_Zero = fill("",n),
    Energy_Price_Stability = fill("",n),
    Funding_Options = fill("",n),
    Energy_Independence = fill("",n),
    Job_Losses = fill("",n),
    Energy_Poverty = fill("",n),
    Avoidable_Deaths_From_Cold = fill( "", n ))

RENAMES = OrderedDict(
    "Q8.2" => "Age",
    "Q8.3" => "Gender",
    "Q8.4" => "Ethnic",
    "Q8.5" => "Postcode",
    "Q8.6"=>"HH_Net_Income_PA",
    "Q8.7"=>"Employment_Status",
    "Q8.8"=>"Owner_Occupier",
    "Q8.9_1"=>"At_Risk_of_Destitution",
    "Q8.10"=>"Managing_Financially",
    "Q8.11"=>"Satisfied_With_Income",
    "Q8.12"=>"Ladder",
    "Q8.13"=>"General_Health",
    "Q8.14"=>"Has_Long_Term_Condition",
    "Q8.15"=>"ADLS_Reduced",
    "Q8.16"=>"Sad_In_Last_Week",
    "Q8.17"=>"Anxious",
    "Q8.18_1"=>"Left_Right",
    "Q8.19" => "Voting_Attitude",
    "Q8.20" => "Vote_Last_Election",
    "Q8.21" => "Vote_Next_Election",
    "Q8.22_1"=>"Politicians_All_The_Same",
    "Q8.22_2"=>"Politics_Force_For_Good",
    "Q8.22_3"=>"Party_In_Government_Doesnt_Matter",
    "Q8.22_4"=>"Politicians_Dont_Care",
    "Q8.22_5"=>"Politicians_Want_To_Make_Things_Better",
    "Q8.22_6"=>"Shouldnt_Rely_On_Government" )

RENAME_VALS = Symbol.(collect( values( RENAMES )))

    #= e.g 
    f39a6972-d430-480e-b9ef-ae05ecda2ca0.1.1_CBCONJOINT	
    d8d883c0-6e6c-4b62-9c3d-9c21df997013.1.1_CBCONJOINT	
    dcf3b3c9-6cf9-41f1-a87c-b568061f2efb.1.1_CBCONJOINT	
    b0be5ee9-8cf2-4ed4-89d3-384d27c4acb6.1.1_CBCONJOINT	
    0dc49323-3297-4edd-a821-b1ce2e3d596b.1.1_CBCONJOINT	
    e8b8552a-79d5-45d6-a8b0-f16822ef2a7c.1.1_CBCONJOINT	
    17084511-ce67-4faf-99d4-99a3ec9b7101.1.1_CBCONJOINT	
    65f88d62-9ea8-449e-a888-b06cd2a8ca24.1.1_CBCONJOINT	
    bf73b87c-8777-48c1-96a1-1e518f393fa4.1.1_CBCONJOINT	
    =#

QLABELS = OrderedDict([
    "f39a6972-d430-480e-b9ef-ae05ecda2ca0"=>"Ownership_Of_Energy_System",
    "d8d883c0-6e6c-4b62-9c3d-9c21df997013"=>"Onwership_Of_N_Sea_Oil",
    "dcf3b3c9-6cf9-41f1-a87c-b568061f2efb"=>"Transition_To_Net_Zero",
    "b0be5ee9-8cf2-4ed4-89d3-384d27c4acb6"=>"Energy_Price_Stability",
    "0dc49323-3297-4edd-a821-b1ce2e3d596b"=>"Funding_Options",
    "e8b8552a-79d5-45d6-a8b0-f16822ef2a7c"=>"Energy_Independence",
    "17084511-ce67-4faf-99d4-99a3ec9b7101"=>"Job_Losses",
    "65f88d62-9ea8-449e-a888-b06cd2a8ca24"=>"Energy_Poverty",
    "bf73b87c-8777-48c1-96a1-1e518f393fa4"=>"Avoidable_Deaths_From_Cold"]) 

QKEYS = Symbol.(collect(keys(QLABELS)))
QVALS = Symbol.(collect(values(QLABELS)))

# nicer (?) names
rename!( qualtrics, RENAMES )

outrow = 0
caseid = 0
for r in eachrow( qualtrics ) # round the conjoint survey
    global outrow,caseid,QKEYS,QVALS,RENAME_VALS
    if r.Finished 
        caseid += 1
        for contest_no in 1:15
            polchoice = Symbol( "C$(contest_no)")
            println("ResponseId=$(r.ResponseId) choice[$(contest_no)] = $(r[polchoice])" )
            # skip missing
            if ! ismissing(r[polchoice])    
                for profile in 1:2
                    outrow += 1
                    or = cjoint_data[outrow,:]
                    or.CaseID = caseid
                    or.profile = profile
                    or.contest_no = contest_no
                    or.ResponseId = r.ResponseId
                    or.chosen_policy = r[polchoice]-1
                    # block copy demogs 
                    for v in RENAME_VALS
                        # println("renaming $v")
                        or[v] = r[v]
                    end
                    for question in 1:9
                        # e.g b0be5ee9-8cf2-4ed4-89d3-384d27c4acb6.1.1_CBCONJOINT
                        polkey = Symbol("$(QKEYS[question]).$(contest_no).$(profile)_CBCONJOINT")
                        outkey = Symbol( QVALS[question])
                        or[outkey] = r[polkey]
                    end
                end # each profile
            end # choice is present
        end # each contest
    end # response was finished
end # each row

# truncate to actual #rows needed
cjoint_data = cjoint_data[1:outrow,:]
# print some stuff
cjoint_data[!,vcat([:CaseID,:contest_no,:chosen_policy],QVALS)]
# dump out
CSV.write( "/mnt/data/ActNow/Energy/energy_data_for_cjoint.tab", cjoint_data; delim='\t')