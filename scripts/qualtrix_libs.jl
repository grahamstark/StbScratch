using DataFrames, CSV, PrettyTables, OrderedCollections, SurveyDataWeighting, GLM, StatsBase

const DATA_DIR="/mnt/data/ActNow/"
"""

"""
function process_qualtrix( 
    cjoint_data :: DataFrame, # weird qualtrix dataframe
    qlabels :: OrderedDict{String,String}, # map from question uuids to our new option labels
    renames :: OrderedDict{String,String},
    num_contests = 15 ) :: DataFrame   # dict of renames Q8.2 => age and so on )::DataFrame
    rename!( cjoint_data, renames )
    # create output df
    N = 100_000 # just initialise output bigger than we'll ever need
    odf = DataFrame(
        ResponseId = fill("", N ),
        CaseID = fill(0, N ), # int person id needed by cjoint
        contest_no = fill( 0, N),
        profile = fill(0,N),
        chosen_profile = fill(0,N)) # which profile this row represents (1 or 2 in our case, could in principle be > 2)
    qkeys = Symbol.(collect(keys(qlabels)))
    qvals = Symbol.(collect(values(qlabels)))
    rename_vals = Symbol.(collect( values(renames)))
    # a field in the output for each age, sex ...
    for v in rename_vals
        et = eltype(skipmissing(cjoint_data[:,v])) # clumsy way to infer types for my output columns.
        println( "v = $v; et=$(et) ")
        if et <: AbstractString
            odf[!,v] = Vector{Union{AbstractString,Missing}}(missing, N)
        else
            odf[!,v] = Vector{Union{Int,Missing}}(missing, N)
        end
    end
    # add the response options
    for v in qvals
        odf[!,v] = fill("", N) 
    end
    num_questions = length(qkeys)
    outrow = 0
    caseid = 0
    # println( "innames= $(names(cjoint_data))" )
    # println( "outnames= $(names(odf))" )
    for r in eachrow( cjoint_data ) # round the conjoint survey
        if r.Finished == 1# Flag for this observation having been completed.
            caseid += 1
            for contest_no in 1:num_contests # there are 15 sets of choices
                polchoice = Symbol( "C$(contest_no)")
                # println("ResponseId=$(r.ResponseId) choice[$(contest_no)] = $(r[polchoice])" )
                # skip missing
                if ! ismissing(r[polchoice])    
                    for profile in 1:2 # 1st choice vs 2nd choice in each contest
                        outrow += 1
                        or = odf[outrow,:]
                        or.CaseID = caseid
                        or.profile = profile
                        or.contest_no = contest_no
                        or.ResponseId = r.ResponseId
                        or.chosen_profile = r[polchoice]-1 # FIXME why did we subtract 1?
                        # println("inrow names $(names(r))")
                        # block copy demogs 
                        for v in rename_vals
                            println("mapping $v")
                            or[v] = r[v]
                        end
                        for question in 1:num_questions # and 9 questions indexed "f39a6972-d430-480e-b9ef-ae05ecda2ca0" .. "bf73b87c-8777-48c1-96a1-1e518f393fa4"
                            # see QLABELS above
                            # e.g b0be5ee9-8cf2-4ed4-89d3-384d27c4acb6.1.1_CBCONJOINT
                            polkey = Symbol("$(qkeys[question]).$(contest_no).$(profile)_CBCONJOINT")
                            outkey = Symbol( qvals[question])
                            or[outkey] = r[polkey]
                        end
                    end # each profile
                end # choice is present
            end # each contest
        end # response was finished
    end
    return odf[1:outrow,:]
end

function new_energy_conjoint()
    energy = CSV.File("/mnt/data/ActNow/new_conjoint/Energy Act Now Conjoint_12 February 2024_12.32_choice_text.tab"; delim='\t', header=1, skipto=4)|>DataFrame
    QLABELS = OrderedDict([
        "f39a6972-d430-480e-b9ef-ae05ecda2ca0"=>"Ownership_Of_Energy_System",
        "d8d883c0-6e6c-4b62-9c3d-9c21df997013"=>"Ownership_Of_N_Sea_Oil",
        "dcf3b3c9-6cf9-41f1-a87c-b568061f2efb"=>"Transition_To_Net_Zero",
        "b0be5ee9-8cf2-4ed4-89d3-384d27c4acb6"=>"Energy_Price_Stability",
        "0dc49323-3297-4edd-a821-b1ce2e3d596b"=>"Funding_Options",
        "e8b8552a-79d5-45d6-a8b0-f16822ef2a7c"=>"Energy_Independence",
        "17084511-ce67-4faf-99d4-99a3ec9b7101"=>"Job_Losses",
        "65f88d62-9ea8-449e-a888-b06cd2a8ca24"=>"Energy_Poverty",
        "bf73b87c-8777-48c1-96a1-1e518f393fa4"=>"Avoidable_Deaths_From_Cold"]) 
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
        "Q8.22_6"=>"Shouldnt_Rely_On_Government",
        "Q6.1_4"=>"Support_Pre",
        "Q7.1_4"=>"Argument_1_Nuclear",
        "Q7.2_4"=>"Support_Post")
       
        odf = process_qualtrix( energy, QLABELS, RENAMES, 15 )
        CSV.write( "/mnt/data/ActNow/new_conjoint/energy_cj_edited.tab", odf; delim='\t')
        energy, odf
end

function new_transport_conjoint()
    transport = CSV.File("/mnt/data/ActNow/new_conjoint/Transport Act Now Conjoint_23 February 2024_13.39_numeric_values.csv", header=1, skipto=4)|>DataFrame
    QLABELS = OrderedDict([
        "4e430a65-d49d-4cc5-aabc-e21d18a3974e" => "Ownership"
        "d7815c98-226e-4f8e-ad83-e0b654e9473f" => "Proportion_of_journeys_by_bike"
        "acb7f745-357d-49ef-bd3c-08cda891f67b" => "Single_fares_within_North_East_transport"
        "c5bea693-2ad0-4990-8bc9-2aef78f76963" => "Average_single_fare_from_Newcastle_to_London"
        "38245c30-d74b-4c8d-b708-a2c07a76c1e2" => "Average_commuting_times"
        "bd3f581e-8ee7-4782-ab0b-387af421b52b" => "Reliability"
        "14c327fd-562d-43c0-878e-db15df2e0294" => "Funding_options"
        "eb520f83-f3a5-4892-935f-740dc9213609" => "Reliance_on_cars"
        "a14bf86e-e191-4e02-b792-eb9240e4d054" => "Congestion"
        "1f6c19fe-fbe6-4970-b393-1fc7a447672a" => "Transport_poverty"
        "e21c9bca-88ac-4c58-bf7d-84bbb106abbe" => "Avoidable_deaths_from_air_pollution" ])

    RENAMES = OrderedDict(
        "Q13.2" => "Age",
        "Q13.3" => "Gender",
        "Q13.4" => "Ethnic",
        "Q13.5" => "Postcode",
        "Q13.6"=>"HH_Net_Income_PA",
        "Q13.7"=>"Employment_Status",
        "Q13.8"=>"Owner_Occupier",
        "Q13.9_1"=>"At_Risk_of_Destitution",
        "Q13.10"=>"Managing_Financially",
        "Q13.11"=>"Satisfied_With_Income",
        "Q13.12"=>"Ladder",
        "Q13.13"=>"General_Health",
        "Q13.14"=>"Has_Long_Term_Condition",
        "Q13.15"=>"ADLS_Reduced",
        "Q13.16"=>"Sad_In_Last_Week",
        "Q13.17"=>"Anxious",
        "Q13.18_1"=>"Left_Right",
        "Q13.19" => "Voting_Attitude",
        "Q13.20" => "Vote_Last_Election",
        "Q13.21" => "Vote_Next_Election",
        "Q13.22_1"=>"Politicians_All_The_Same",
        "Q13.22_2"=>"Politics_Force_For_Good",
        "Q13.22_3"=>"Party_In_Government_Doesnt_Matter",
        "Q13.22_4"=>"Politicians_Dont_Care",
        "Q13.22_5"=>"Politicians_Want_To_Make_Things_Better",
        "Q13.22_6"=>"Shouldnt_Rely_On_Government",
        "Q6.1_4"=>"Support_Pre",
        "Q7.1_4"=>"Argument_1_Affordable",
        "Q8.1_4"=>"Argument_2_Same_As_London",
        "Q9.1_4"=>"Argument_3_Privatisation_Failed",
        "Q10.1_4"=>"Argument_4",
        "Q11.1_4"=>"Argument_5_Improve_Environment",
        "Q12.1_4"=>"Support_Post")

    odf = process_qualtrix( transport, QLABELS, RENAMES, 15 )
    CSV.write( "/mnt/data/ActNow/new_conjoint/transport_cj_edited.tab", odf; delim='\t')
    transport, odf
end

function gender(i)
    return if i == 1
      "Male"
    elseif i == 2
      "Female"
    elseif i == 3
      "Other"
    end
end

function polparty(i)
    return if i == 1
        "Brexit"
    elseif i == 2
        "Conservative"
    elseif i == 3
        "Green Party"
    elseif i == 4
        "Labour"
    elseif i == 5
        "Liberal Democrats"
    elseif i == 11
        "Plaid Cymru"
    elseif i == 12
        "Scottish National Party"
    elseif i == 6
        "Independent"
    elseif i == 7
        "Other"
    elseif i == 8
        "Chose not to vote"
    elseif i == 9
        "Not eligible"
    elseif i == 10
        "Prefer not to say"
    end
end


#
# Weighting - target set. See `.ods` spreadsheet in `data`.
#
const TARGET_SET = [
    5464261.0,	#	m18-30 1
    8576471,	#	m31-50 2
    6435265,	#	m51-65 3
    5483397,	#	m'66+  4
    5443882,	#	f18-30 5
    9030913,	#	f31-50 6
    6689300,	#	f51-65 7
    6523340,	#	f66+   8
    12963893,	#	Labour 9
    6914076,	#	Conservatives 10
    3168952,	#	Reform/Other 11
    2880865,	#	Lib Dem 12
    2880865]	#	Greens, etc 13
    # 24838177]	#	No Vote - omit collinear


function make_target_set( dall :: DataFrame ) :: Tuple

    function age_slot( gender :: String, age :: Int  )
        a = if age <= 30
            1
        elseif age <= 50
            2
        elseif age <= 65
            3
        else
            4
        end
        return gender == "Male" ? a : a+4
    end

    ncols = length( TARGET_SET )
    nrows = size(dall)[1]
    m = zeros(nrows,ncols)
    row = 1
    for r in eachrow( dall )
        sex = if r.Gender in  ["Male","Female"]
            r.Gender
        else
            rand( ["Male", "Female"])
        end
        at = age_slot( sex, r.Age )
        m[row,at] = 1.0
        pol = if r.next_election == "Labour"
            1
        elseif r.next_election == "Conservative"   # => 792
            2
        elseif r.next_election == "Other/Brexit"     #  => 75
            3
        elseif r.next_election == "LibDem"            # => 116
            4
        elseif r.next_election == "Nat/Green"         # => 137
            5
        elseif r.next_election == "No Vote/DK/Refused" # => 382
            6
        else
            @assert false "unrecognised $(r.next_election)"
        end
        at = pol + 8
        if at <= 13 # skip dks
            m[row,at] = 1.0
        end
        row += 1
    end
    pop = sum(TARGET_SET[1:8])
    w = pop/nrows
    initial_weights = fill( w, nrows )
    m, initial_weights
end

"""
Create weights based on voting intention and age/sex groups.
NOTE: 0.6-2.8 are the closesy weights I can find that converge using constrained_chi_square.
"""
function reweight( 
    dall :: DataFrame, 
    lower_multiple = 0.60, 
    upper_multiple = 2.8 )::AbstractWeights 
    data, initial_weights = make_target_set( dall )
    weights = do_reweighting(
        data               = data,
        initial_weights    = initial_weights,
        target_populations = TARGET_SET,
        functiontype       = constrained_chi_square,
        lower_multiple     = lower_multiple,
        upper_multiple     = upper_multiple )
    return Weights( weights )
end 
