#
# 
#
using GLM,DataFrames,CSV,Pluto,CairoMakie,CategoricalArrays,RegressionTables

DATA_DIR="/mnt/data/ActNow/Surveys/live/"

RENAMES = Dict(
    "Q65.2_1"=>"Support_All_Policies",
    "Q65.3_1"=>"Any_Argument",
    "Q66.2"=>"Age",
    "Q66.3"=>"Gender",
    "Q66.3_3_TEXT"=>"Gender_Other",
    "Q66.4"=>"Ethnic",
    "Q66.4_5_TEXT"=>"Ethnic_White_Other",
    "Q66.4_9_TEXT"=>"Ethnic_Mixed_Other",
    "Q66.4_14_TEXT"=>"Ethnic_Asian_Other",
    "Q66.4_17_TEXT"=>"Ethnic_Black_Other",
    "Q66.4_19_TEXT"=>"Ethnic_Other_Other", # check all these for any entry
    "Q66.5"=>"Postcode4",
    "Q66.6"=>"HH_Net_Income_PA",
    "Q66.7"=>"Employment_Status",
    "Q66.7_13_TEXT"=>"Employment_Status_Other",
    "Q66.8"=>"Owner_Occupier",
    "Q66.9_1"=>"At_Risk_of_Destitution",
    "Q66.10"=>"Managing_Financially",
    "Q66.11"=>"Satisfied_With_Income",
    "Q66.12"=>"Ladder",
    "Q66.13"=>"General_Health",
    "Q9.1_1"=>"Little_interest_in_things",
    "Q9.1_2"=>"Depressed",
    "Q9.1_3"=>"Trouble_Sleeping",
    "Q9.1_4_1"=>"No_Energy",
    "Q9.1_5"=>"Poor_Appetite",
    "Q9.1_6"=>"Feeling_Failure",
    "Q9.1_7"=>"Trouble_Concentrating",
    "Q9.1_8"=>"More_Restless_Than_Usual",
    "Q66.15_1"=>"Anxious",
    "Q66.15_2"=>"Uncontrolled_Worry",
    "Q66.15_3"=>"Worrying_To_Much",
    "Q66.15_4"=>"Trouble_Relaxing",
    "Q66.15_5"=>"Restless_Cant_Sit_Still",
    "Q66.15_6"=>"Easily_Annoyed",
    "Q66.15_7"=>"Afraid",
    "Q66.16"=>"Think_About_Future",
    "Q66.17_1"=>"In_Control_Of_Life",
    "Q66.18_1"=>"Life_Satisfaction",
    "Q66.19"=>"Change_in_circumstance",
    "Q66.20_1"=>"Left_Right",
    "Q66.21"=>"Voting",
    "Q66.22"=>"Party_Last_Election",
    "Q66.22_9_TEXT"=>"Party_Last_Election_Other",
    "Q66.23"=>"Party_Next_Election",
    "Q66.23_9_TEXT"=>"Party_Next_Election_Other",
    "Q66.24_1"=>"Politicians_All_The_Same",
    "Q66.24_2"=>"Politics_Force_For_Good’",
    "Q66.24_3"=>"Party_In_Government_Doesnt_Matter",
    "Q66.24_4"=>"Politicians_Dont_Care",
    "Q66.24_5"=>"Politicians_Want_To_Make_Things_Better",
    "Q66.24_6"=>"Shouldnt_Rely_On_Government" )

function create_one!( dall::DataFrame; label :: String, initialq :: String, finalq :: String, treatqs :: Vector{String} )
    dall[:,"$(label)_treat_absgains_v"] = dall[:,"$(treatqs[1])"]
    
    dall[:,"$(label)_treat_absgains"] = ( .! ismissing.( dall[:,"$(treatqs[1])"] ) )
    dall[:,"$(label)_treat_relgains"] = ( .! ismissing.( dall[:,"$(treatqs[2])"] ) )
    dall[:,"$(label)_treat_security"] = ( .! ismissing.( dall[:,"$(treatqs[3])"] ) )
    dall[:,"$(label)_treat_other_argument"] = ( .! ismissing.( dall[:,"$(treatqs[4])"] ) )
    rename!( dall, Dict(initialq => "$(label)_pre", (finalq => "$(label)_post" )))
    dall[:,"$(label)_change"] = dall[:,"$(label)_post"] - dall[:,"$(label)_pre"]
    dall[:,"$(label)_strong_approve_pre"] = dall[:,"$(label)_pre"] .>= 70
    dall[:,"$(label)_strong_approve_post"] = dall[:,"$(label)_post"] .>= 70
    # interaction terms with old or 
    dall[:,"$(label)_treat_absgains_old_or_destitute"] = dall.old_or_destitute .* dall[:,"$(label)_treat_absgains"]
    dall[:,"$(label)_treat_relgains_old_or_destitute"] = dall.old_or_destitute .* dall[:,"$(label)_treat_relgains"]
    dall[:,"$(label)_treat_security_old_or_destitute"] = dall.old_or_destitute .* dall[:,"$(label)_treat_security"]
    dall[:,"$(label)_treat_other_argument_old_or_destitute"] = dall.old_or_destitute .* dall[:,"$(label)_treat_other_argument"]

    dall[:,"$(label)_treat_absgains_destitute"] = dall.destitute .* dall[:,"$(label)_treat_absgains"]
    dall[:,"$(label)_treat_relgains_destitute"] = dall.destitute .* dall[:,"$(label)_treat_relgains"]
    dall[:,"$(label)_treat_security_destitute"] = dall.destitute .* dall[:,"$(label)_treat_security"]
    dall[:,"$(label)_treat_other_argument_destitute"] = dall.destitute .* dall[:,"$(label)_treat_other_argument"]
end


function recode_income( inc )
    return if ismissing( inc )
        missing
    elseif inc < 100
      inc * 1000
    else
     inc
  end
end

outf = open( "tmp/red-wall-regressions.txt", "w")

dn = CSV.File("$(DATA_DIR)/national_censored.csv")|>DataFrame
dr = CSV.File("$(DATA_DIR)/red_censored.csv")|>DataFrame
dn.is_redwall .= false
dr.is_redwall .= true

dall = vcat(dn,dr)

CSV.write( "$(DATA_DIR)/national_censored.tab", dall; delim='\t')

function recode_ethnic( ethnic :: AbstractString ) :: String
    return ethnic == "1. English, Welsh, Scottish, Northern Irish or British" ? "Ethnic British" : "Other Ethnic" 
end

function recode_party( party :: AbstractString ) :: String
    return if party in ["Conservative Party"]
        "Conservative"
    elseif party in ["Green Party", "Plaid Cymru", "Scottish National Party"]
        "Nat/Green"
    elseif party in ["Labour Party"]
        "Labour"
    elseif party in ["Liberal Democrats"]
        "LibDem"
    elseif party in ["Other (please name below)", "Independent candidate","Brexit Party"]
        "Other/Brexit"
    else 
        "No Vote/DK/Refused"
    end
end

function recode_employment( employment :: AbstractString ) :: String
    return if employment in [
        "In full-time paid work (30 or more hours a week)"
        "In irregular or occasional work"
        "Self-employed"
        "In part-time paid work (less than 30 hours a week)"]
        "Working/SE Inc. Part-Time"
    else
        "Not Working, Inc. Retired/Caring/Student"
    end
end

# needs to be done before renaming..
dall.old_or_destitute = (dall."Q66.2" .>= 50) .| (dall."Q66.9_1" .>= 70)
dall.destitute = (dall."Q66.9_1" .>= 70)

create_one!( dall; label="basic_income", initialq="Q5.1_4", finalq="Q10.1_4", treatqs=["Q6.1_4","Q7.1_4","Q8.1_4","Q9.1_4"])
create_one!( dall; label="green_nd", initialq="Q11.1_4", finalq="Q16.1_4", treatqs=["Q12.1_4","Q13.1_4","Q14.1_4","Q15.1_4"])
create_one!( dall; label="utilities", initialq="Q17.1_4", finalq="Q22.1_4", treatqs=["Q18.1_4","Q19.1_4","Q20.1_4","Q21.1_4"])
create_one!( dall; label="health", initialq="Q23.1_4", finalq="Q28.1_4", treatqs=["Q24.1_4","Q25.1_4","Q26.1_4","Q27.1_4"])
create_one!( dall; label="childcare", initialq="Q29.1_4", finalq="Q34.1_4", treatqs=["Q30.1_4","Q31.1_4","Q32.1_4","Q33.1_4"])
create_one!( dall; label="education", initialq="Q35.1_4", finalq="Q40.1_4", treatqs=["Q36.1_4","Q37.1_4","Q38.1_4","Q39.1_4"])
create_one!( dall; label="housing", initialq="Q41.1_4", finalq="Q46.1_4", treatqs=["Q42.1_4","Q43.1_4","Q44.1_4","Q45.1_4"])
create_one!( dall; label="transport", initialq="Q47.1_4", finalq="Q52.1_4", treatqs=["Q48.1_4","Q49.1_4","Q50.1_4","Q51.1_4"])
create_one!( dall; label="democracy", initialq="Q53.1_4", finalq="Q58.1_4", treatqs=["Q54.1_4","Q55.1_4","Q56.1_4","Q57.1_4"])
create_one!( dall; label="tax", initialq="Q59.1_4", finalq="Q64.1_4", treatqs=["Q60.1_4","Q61.1_4","Q62.1_4","Q63.1_4"])

rename!( dall, RENAMES )
# dall = dall[dall.HH_Net_income_PA .> 0,:] # skip zeto incomes 
dall = dall[(.! ismissing.(dall.HH_Net_Income_PA )) .& (dall.HH_Net_Income_PA .> 0),:]

dall.HH_Net_Income_PA .= recode_income.( dall.HH_Net_Income_PA)
dall.ethnic_2 = recode_ethnic.( dall.Ethnic )
dall.last_election = recode_party.( dall.Party_Last_Election )
dall.employment_2 = recode_employment.(dall.Employment_Status)
dall.log_income = log.(dall.HH_Net_Income_PA)
dall.age_sq = dall.Age .^2
dall.Gender= convert.(String,dall.Gender)
dall.Owner_Occupier= convert.(String,dall.Owner_Occupier)
dall.General_Health= convert.(String,dall.General_Health)
dall.Little_interest_in_things = convert.(String,dall.Little_interest_in_things )

close( outf )
# annoying strings

POLICIES = [:basic_income, :green_nd, :utilities, :health, :childcare, :education, :housing, :transport, :democracy, :tax]

regs=[]
simpleregs = []
for policy in POLICIES
    depvar = Symbol( "$(policy)_pre")
    v = lm( @eval(@formula( $(depvar) ~ 
        Age + Age^2 + Age^3 + last_election+ ethnic_2 + employment_2 + 
        log(HH_Net_Income_PA) + Owner_Occupier + is_redwall + Gender + 
        At_Risk_of_Destitution)), dall )
    push!( regs, v )
    v = lm( @eval(@formula( $(depvar) ~ 
        Age + Age^2 + Age^3 + At_Risk_of_Destitution)), dall)
    push!( simpleregs, v )
end 

##  + Ladder + General_Health + Little_interest_in_things

absgain_regs=[]
for policy in POLICIES
    depvar = Symbol( "$(policy)_treat_absgains_v")
    v = lm( @eval(@formula( $(depvar) ~ Age + Age^2 + Age^3 + last_election + ethnic_2 + employment_2 + log(HH_Net_Income_PA) + Owner_Occupier + is_redwall + Gender + At_Risk_of_Destitution )), dall )
    push!( absgain_regs, v )
end 

diffregs_simple=[]
for policy in POLICIES
    depvar = Symbol( "$(policy)_change")
    relgains = Symbol( "$(policy)_treat_relgains" )
    relsec =Symbol( "$(policy)_treat_security" )
    relflourish = 
        Symbol( "$(policy)_treat_other_argument" )
    absgains_destitute = 
        Symbol( "$(policy)_treat_absgains_destitute" )
    relgains_destitute = 
        Symbol( "$(policy)_treat_relgains_destitute" )
    relsec_destitute = 
        Symbol( "$(policy)_treat_security_destitute" )
    relflourish_destitute = Symbol("$(policy)_treat_other_argument_destitute" )    
    v = lm( @eval(@formula( $(depvar) ~ $(absgains_destitute) + $(relgains) + $(relsec) + $(relflourish) + $(relgains_destitute) + $(relsec_destitute) + $(relflourish_destitute) )), dall )
    push!( diffregs_simple, v )
end 

regtable(regs[1:5]...;file="tmp/actnow-ols-1-5.html",stat_below = false, render=HtmlTable())
regtable(regs[6:10]...;file="tmp/actnow-ols-6-10.html",stat_below = false, render=HtmlTable())

regtable(simpleregs[1:5]...;file="tmp/actnow-simple-ols-1-5.html",stat_below = false, render=HtmlTable())
regtable(simpleregs[6:10]...;file="tmp/actnow-simple-ols-6-10.html",stat_below = false, render=HtmlTable())

regtable(absgain_regs[1:5]...;file="tmp/actnow-absgain-ols-1-5.html",stat_below = false, render=HtmlTable())
regtable(absgain_regs[6:10]...;file="tmp/actnow-absgains-ols-6-10.html",stat_below = false, render=HtmlTable())

regtable(diffregs_simple[1:5]...;file="tmp/actnow-change-simple-ols-1-5.html",stat_below = false, render=HtmlTable())
regtable(diffregs_simple[6:10]...;file="tmp/actnow-change-simple-ols-6-10.html",stat_below = false, render=HtmlTable())

# v = glm( @formula( basic_income_strong_approve_pre ~ Age + Age^2 + Party_Last_Election+ Ethnic + Employment_Status + log(HH_Net_Income_PA) + Owner_Occupier + is_redwall + Gender ), dall, Binomial(), ProbitLink() )

for policy in POLICIES
    f = Figure()
    scats = []
    ax = Axis(f[1,1],title="$(policy) : pre- and post- treatment by argument type.",xlabel="Pre",ylabel="Post")
    for d in ["treat_absgains","treat_relgains","treat_security","treat_other_argument"]
        treatment = "$(policy)_$(d)"
        pre = "$(policy)_pre"
        post = "$(policy)_post"
        dd = dall[dall[:,treatment] .> 0,:]
        x = scatter!( ax, dd[:,pre], dd[:,post] )
        push!(scats,x)
    end
    Legend( f[1,2],scats,["Absolute Gains","Relative Gains","Security","The Other Argument"])
    save( "tmp/img/$(policy)_pre_post.svg", f )
end

for policy in POLICIES
    println( "<img src='img/$(policy)_pre_post.svg' />")
end


