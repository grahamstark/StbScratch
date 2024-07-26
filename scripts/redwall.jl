#
# 
#
using GLM,DataFrames,CSV,Pluto,CairoMakie,CategoricalArrays,RegressionTables
using ScottishTaxBenefitModel
using .Utils 

DATA_DIR="/mnt/data/ActNow/Surveys/live/"

const MAIN_EXPLANVARS = [
    :destitute, 
    :poorhealth,
    :unsatisfied_with_income,
    :Owner_Occupier, 
    :down_the_ladder,
    :not_managing_financially]

#=
Q66.6 # HH_Net_Income_PA
Q66.8 # Owner_Occupier
Q66.9_1 # At_Risk_of_Destitution
Q66.10  # "Managing_Financially"
Q66.11  # Satisfied_With_Income
Q66.12  # Ladder
Q66.13  # General_Health
=#

function corrmatrix( df, keys ) :: DataFrame
    corrtars = Symbol.(string.(keys).*"_pre")
    n = length(keys)
    corrs = cor(Matrix(dr[:,corrtars]))
    corrs = convert(Array{Union{Float64,Missing}},corrs)    
    println(corrs)
    for r in 1:n
        for c in (r+1):n
            corrs[r,c] = missing
        end
    end
    labels = pretty.(keys)
    df = DataFrame( corrs, labels )
    df." " = labels
    df
end

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

"""
This convoluted function creates a bunch or binary variables in the dataframe `dall` for some question and treatments.
    @param `labels` - for readable variable names e.g. "basic_income"
    @param `initialq` - initial opinion on the thing
    @param `finalq` - final (post explanation) opinion
    @param `treatqs` - three strings representing the 3 explanations for that thing - abs gains, rel gains, security
    adds in variables like `basic_income_treat_absgains_destitute`
"""
function create_one!( 
    dall::DataFrame; 
    label :: String, 
    initialq :: String, 
    finalq :: String, 
    treatqs :: Vector{String} )
    dall[:,"$(label)_treat_absgains_v"] = dall[:,"$(treatqs[1])"]
    
    # identify subsets wo
    dall[:,"$(label)_treat_absgains"] = ( .! ismissing.( dall[:,"$(treatqs[1])"] ) )
    dall[:,"$(label)_treat_relgains"] = ( .! ismissing.( dall[:,"$(treatqs[2])"] ) )
    dall[:,"$(label)_treat_security"] = ( .! ismissing.( dall[:,"$(treatqs[3])"] ) )
    dall[:,"$(label)_treat_other_argument"] = ( .! ismissing.( dall[:,"$(treatqs[4])"] ) )
    rename!( dall, Dict(initialq => "$(label)_pre", (finalq => "$(label)_post" )))
    dall[:,"$(label)_change"] = dall[:,"$(label)_post"] - dall[:,"$(label)_pre"]
    dall[:,"$(label)_strong_approve_pre"] = dall[:,"$(label)_pre"] .>= 70
    dall[:,"$(label)_strong_approve_post"] = dall[:,"$(label)_post"] .>= 70
    
    dall[:,"$(label)_treat_absgains_destitute"] = dall.destitute .* dall[:,"$(label)_treat_absgains"]
    dall[:,"$(label)_treat_relgains_destitute"] = dall.destitute .* dall[:,"$(label)_treat_relgains"]
    dall[:,"$(label)_treat_security_destitute"] = dall.destitute .* dall[:,"$(label)_treat_security"]
    dall[:,"$(label)_treat_other_argument_destitute"] = dall.destitute .* dall[:,"$(label)_treat_other_argument"]
end


function recode_income( inc )
    return if ismissing( inc )
        missing
    elseif inc < 1000
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
# dall.old_or_destitute = (dall."Q66.2" .>= 50) .| (dall."Q66.9_1" .>= 70)
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
dall.age5 = dall.Age .÷ 5
dall.poorhealth = dall.General_Health .∈ (["Bad","Very bad"],)
dall.unsatisfied_with_income = dall.Satisfied_With_Income .∈ ( 
    ["1. Completely dissatisfied","2. Mostly dissatisfied", "3. Somewhat dissatisfied]"], )
dall.not_managing_financially = dall.Managing_Financially .∈ ( 
    ["5. Finding it very difficult", "4.\tFinding it quite difficult"], )
dall.down_the_ladder = dall.Ladder .<= 4

#
# Dump modified data
#
CSV.write( joinpath( DATA_DIR, "national-w-created-vars.tab"), dall; delim='\t')

close( outf )


const POLICIES = [:basic_income, :green_nd, :utilities, :health, :childcare, :education, :housing, :transport, :democracy, :tax]


function runregressions( mainvar :: Symbol )
    #
    # regressions: for each policy, before the explanation, do a big regression and a simple one and add them to a list
    # the convoluted `@eval(@formula( $(depvar)` bit just allows to sub in each dependent variable `$(depvar)`
    #
    regs=[]
    simpleregs = []
    for policy in POLICIES
        depvar = Symbol( "$(policy)_pre")
        reg = lm( @eval(@formula( $(depvar) ~ 
            Age + Age^2 + last_election+ ethnic_2 + employment_2 + 
            log(HH_Net_Income_PA) + Owner_Occupier + is_redwall + Gender + 
            $(mainvar))), dall )
        push!( regs, reg )
        reg = lm( @eval(@formula( $(depvar) ~ 
            Age + Age^2 + $( mainvar ))), dall)
        push!( simpleregs, reg )
    end 
    #
    # regression of change in popularity of each policy against each explanation
    #
    diffregs=[]
    for policy in POLICIES
        depvar = Symbol( "$(policy)_change")
        relgains = Symbol( "$(policy)_treat_relgains" )
        relsec =Symbol( "$(policy)_treat_security" )
        absgains =Symbol( "$(policy)_treat_absgains" )
        relflourish = 
            Symbol( "$(policy)_treat_other_argument" )
        reg = lm( @eval(@formula( $(depvar) ~ $(relgains) + $(relsec) + $(relflourish) + 
            $(absgains)*$(mainvar) + $(relgains)*$(mainvar) + $(relsec)*$(mainvar) + 
            $(relflourish)*$(mainvar) )), dall )
        push!( diffregs, reg )
    end 

    regtable(regs[1:5]...;file="tmp/actnow-$(mainvar)-ols-1-5.html",stat_below = false, render=HtmlTable())
    regtable(regs[6:10]...;file="tmp/actnow-$(mainvar)-ols-6-10.html",stat_below = false, render=HtmlTable())

    regtable(simpleregs[1:5]...;file="tmp/actnow-simple-$(mainvar)-ols-1-5.html",stat_below = false, render=HtmlTable())
    regtable(simpleregs[6:10]...;file="tmp/actnow-simple-$(mainvar)-ols-6-10.html",stat_below = false, render=HtmlTable())

    regtable(diffregs[1:5]...;file="tmp/actnow-change-$(mainvar)-ols-1-5.html",stat_below = false, render=HtmlTable())
    regtable(diffregs[6:10]...;file="tmp/actnow-change-$(mainvar)-ols-6-10.html",stat_below = false, render=HtmlTable())

    # v = glm( @formula( basic_income_strong_approve_pre ~ Age + Age^2 + Party_Last_Election+ Ethnic + Employment_Status + log(HH_Net_Income_PA) + Owner_Occupier + is_redwall + Gender ), dall, Binomial(), ProbitLink() )
    #=
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
    =#
end

for mainvar in MAIN_EXPLANVARS
    runregressions( mainvar )
end

POLICIES 
const POL_COLS = scale_color_manual( :blue,:red,:orange,:green,:grey,:purple )
const BLANK = ggplot() + 
    theme( xticklabelsvisible = false, xgridvisible = false, yticklabelsvisible = false,
        ygridvisible = false, xtickcolor = :transparent, ytickcolor = :transparent, 
        bottomspinevisible = false, topspinevisible = false, rightspinevisible = false, 
        leftspinevisible = false )


function draw_policies( dr::DataFrame, pol :: Symbol ) :: Tuple
    policy = Symbol("$(pol)_pre")
    label = pretty( pol )
    title = "$(label) vs Democratic Preference (before treatment)"
    # polcolours = parse.(Colorant,[])
    sp = aes( x=:democracy_pre, y=policy )
    scatter = ggplot(dr, sp ) + 
        geom_point( @aes(color=last_election ), size=4 ) +
        geom_smooth() +
        labs(x = "Democracy", y = label, title=title ) +
        POL_COLS
    democ = ggplot(dr) +
        geom_histogram( aes(:democracy_pre )) + 
        theme(xticklabelsvisible = false, xgridvisible = false)
    polplot = ggplot(dr) +
        geom_histogram( aes( policy ), direction = :x) + 
        theme(yticklabelsvisible = false, ygridvisible = false)
    p = democ + BLANK + scatter + polplot + 
        plot_layout(ncol = 2, nrow = 2, widths = [2, 1], heights = [1, 2])
    f = ggplot(dr, sp ) + 
        geom_point(size=4) +
        # geom_smooth() +
        labs(x = "Democracy", y = label ) +
        facet_wrap( :last_election ) 
    p, scatter, f
end

for p in POLICIES 
    title = pretty( string(p))
    if p !== :democracy 
        threeplot, scatter, facet = draw_policies( dr, p )
        ggsave( "tmp/actnow-$(p)-multi.svg", threeplot; scale=1,height=800, width=800)
        ggsave( scatter, "tmp/actnow-$(p)-scatter.svg" )
        ggsave( facet, "tmp/actnow-$(p)-facet.svg" )
    end
end