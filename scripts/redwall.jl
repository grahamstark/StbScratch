#
# 
#
using AlgebraOfGraphics,
    CairoMakie,
    CategoricalArrays,
    ColorSchemes,
    CSV,
    DataFrames,
    GLM,
    PrettyTables,
    RegressionTables,
    StatsBase,
    SurveyDataWeighting,
    Tidier

using ScottishTaxBenefitModel
using .Utils 

DATA_DIR="/mnt/data/ActNow/Surveys/live/"

const MAIN_EXPLANDICT = Dict([
    "destitute"=>"At Risk Of Destitution", 
    "poorhealth" => "In Poor Health",
    "unsatisfied_with_income" => "Unsatisfied with Income",
    "Owner_Occupier" => "Owner Occupier, inc. with a Mortgage", 
    "down_the_ladder" => "Low Life Satisfaction (Life Ladder 1..4)",
    "not_managing_financially" => "Not Managing Well Financially"])

const MAIN_EXPLANVARS = Symbol.(collect((keys( MAIN_EXPLANDICT ))))

const POLICIES = [:basic_income, :green_nd, :utilities, :health, :childcare, :education, :housing, :transport, :democracy, :tax]
const RENAMES = Dict(
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

#=
Q66.6 # HH_Net_Income_PA
Q66.8 # Owner_Occupier
Q66.9_1 # At_Risk_of_Destitution
Q66.10  # "Managing_Financially"
Q66.11  # Satisfied_With_Income
Q66.12  # Ladder
Q66.13  # General_Health
=#

#
# Formatting routines for PrettyTables
#
form( v :: Missing, i, j ) = ""
form( v :: AbstractString, i, j ) = v
form( v :: Integer, i, j ) = "$v"
form( v :: Number, i, j ) = Format.format(v; precision=2 )

"""
Correlation matrix for the policies
"""
function corrmatrix( df, keys, pre_or_post = "pre" ) :: DataFrame
    corrtars = Symbol.(string.(keys).*pre_or_post)
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
    
    # identify subsets who heard the absolute/relative/security arguments
    dall[:,"$(label)_treat_absgains"] = ( .! ismissing.( dall[:,"$(treatqs[1])"] ) )
    dall[:,"$(label)_treat_relgains"] = ( .! ismissing.( dall[:,"$(treatqs[2])"] ) )
    dall[:,"$(label)_treat_security"] = ( .! ismissing.( dall[:,"$(treatqs[3])"] ) )
    dall[:,"$(label)_treat_other_argument"] = ( .! ismissing.( dall[:,"$(treatqs[4])"] ) )
    rename!( dall, Dict(initialq => "$(label)_pre", (finalq => "$(label)_post" )))
    # change after hearing argument
    dall[:,"$(label)_change"] = dall[:,"$(label)_post"] - dall[:,"$(label)_pre"]
    dall[:,"$(label)_strong_approve_pre"] = dall[:,"$(label)_pre"] .>= 70
    dall[:,"$(label)_strong_approve_post"] = dall[:,"$(label)_post"] .>= 70
    
    # interactions of fear of destitution and the 4 different arguments
    dall[:,"$(label)_treat_absgains_destitute"] = dall.destitute .* dall[:,"$(label)_treat_absgains"]
    dall[:,"$(label)_treat_relgains_destitute"] = dall.destitute .* dall[:,"$(label)_treat_relgains"]
    dall[:,"$(label)_treat_security_destitute"] = dall.destitute .* dall[:,"$(label)_treat_security"]
    dall[:,"$(label)_treat_other_argument_destitute"] = dall.destitute .* dall[:,"$(label)_treat_other_argument"]
end

"""
Hacky fix of incomew were some people seem to have entered in £000s rather than £s
"""
function recode_income( inc )
    return if ismissing( inc )
        missing
    elseif inc < 100
        inc * 1000
    else
        inc
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
NOTE: 0.6-2.8 are the closed weights I can find that converge using constrained_chi_square.
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


function make_dataset()::DataFrame
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
    dall.next_election = recode_party.( dall.Party_Next_Election )
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
    # rename!( dall, ["last_election"=>"Party Vote Last Election"])

    #
    # Dump modified data
    #
    dall.weight = reweight( dall )
    CSV.write( joinpath( DATA_DIR, "national-w-created-vars.tab"), dall; delim='\t')
    return dall
end # make dataset

function make_labels()::Dict{String,String}
    d = Dict{String,String}()
    for policy in POLICIES
        pp = pretty( policy )
        d["$(policy)_change"] = "$pp"
        d["$(policy)_pre"] = "$pp"
        d["$(policy)_post"] = "$pp"
        d["$(policy)_treat_relgains"] = "Shown Relative Gains Argument"
        d["$(policy)_treat_security"] = "Shown Security Argument"
        d["$(policy)_treat_absgains"] = "Shown Absolute Gains Argument"
        d["$(policy)_treat_other_argument"] = "Shown Flourishing Argument"
    end
    d["is_redwall"] = "From Redwall Constituency"
    # d["destitute"] = "At Risk of Destitution"
    d["log(HH_Net_Income_PA)"] = "Log of household annual net income"
    d["ethnic_2: Other Ethnic"] = "Not Ethnically British"
    d["Gender: In another way (please type in below)"] = "Other Gender/Gender not specified"
    d["employment_2: Working/SE Inc. Part-Time"] = "Working or Self Employed (inc. part-time)"
    return merge(d, MAIN_EXPLANDICT )
end



function run_regressions( dall::DataFrame, mainvar :: Symbol )
    #
    # regressions: for each policy, before the explanation, do a big regression and a simple one and add them to a list
    # the convoluted `@eval(@formula( $(depvar)` bit just allows to sub in each dependent variable `$(depvar)`
    #
    regs=[]
    simpleregs = []
    for policy in POLICIES
        depvar = Symbol( "$(policy)_pre")
        reg = lm( @eval(@formula( $(depvar) ~ 
            Age + Age^2 + next_election + ethnic_2 + employment_2 + 
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
        #=
        reg = lm( @eval(@formula( $(depvar) ~ $(relgains) + $(relsec) + $(relflourish) + 
            $(absgains)*$(mainvar) + $(relgains)*$(mainvar) + $(relsec)*$(mainvar) + 
            $(relflourish)*$(mainvar) )), dall )
        =#
        reg = lm( @eval(@formula( $(depvar) ~ $(relgains) + $(relflourish) + $(relsec) + $(mainvar))), dall )
            # $(absgains)*$(mainvar) + $(relgains)*$(mainvar) + $(relsec)*$(mainvar) + 
            # $(relflourish)*$(mainvar) )), dall )
        push!( diffregs, reg )
    end 

    labels = make_labels()
    regtable(regs...;file="tmp/actnow-$(mainvar)-ols.html",number_regressions=false, stat_below = false, render=HtmlTable(), labels=labels)
    regtable(simpleregs...;file="tmp/actnow-simple-$(mainvar)-ols.html",number_regressions=false, stat_below = false, render=HtmlTable(), labels=labels)
    regtable(diffregs...;file="tmp/actnow-change-$(mainvar)-ols.html",number_regressions=false, stat_below = false, render=HtmlTable(), labels=labels)
    regtable(regs...;file="tmp/actnow-$(mainvar)-ols.txt",number_regressions=false, stat_below = false, render=AsciiTable(), labels=labels)
    regtable(simpleregs...;file="tmp/regressions/actnow-simple-$(mainvar)-ols.txt",number_regressions=false, stat_below = false, render=AsciiTable(), labels=labels)
    regtable(diffregs...;file="tmp/regressions/actnow-change-$(mainvar)-ols.txt",number_regressions=false, stat_below = false, render=AsciiTable(), labels=labels)
    regtable(regs...;file="tmp/regressions/actnow-$(mainvar)-ols.tex",number_regressions=false, stat_below = false, render=LatexTable(), labels=labels)
    regtable(simpleregs...;file="tmp/regressions/actnow-simple-$(mainvar)-ols.tex",number_regressions=false, stat_below = false, render=LatexTable(), labels=labels)
    regtable(diffregs...;file="tmp/regressions/actnow-change-$(mainvar)-ols.tex",number_regressions=false, stat_below = false, render=LatexTable(), labels=labels)

    #=
    regtable(regs[1:5]...;file="tmp/actnow-$(mainvar)-ols-1-5.html",number_regressions=false, stat_below = false, render=HtmlTable(), labels=labels)
    regtable(regs[6:10]...;file="tmp/actnow-$(mainvar)-ols-6-10.html",number_regressions=false, stat_below = false, render=HtmlTable(), labels=labels)
    =#
    #=
    regtable(simpleregs[1:5]...;file="tmp/actnow-simple-$(mainvar)-ols-1-5.html",number_regressions=false, stat_below = false, render=HtmlTable(), labels=labels)
    regtable(simpleregs[6:10]...;file="tmp/actnow-simple-$(mainvar)-ols-6-10.html",number_regressions=false, stat_below = false, render=HtmlTable(), labels=labels)
    =#
    #=
    regtable(diffregs[1:5]...;file="tmp/actnow-change-$(mainvar)-ols-1-5.html",number_regressions=false, stat_below = false, render=HtmlTable(), labels=labels)
    regtable(diffregs[6:10]...;file="tmp/actnow-change-$(mainvar)-ols-6-10.html",number_regressions=false, stat_below = false, render=HtmlTable(), labels=labels)
    =#
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

function edit_table( io, tablename )
    lines = readlines(tablename)
    table = lines[15:end]
    insert!(table, 1, "<table class='table table-sm table-striped'>")
    for t in table
        t = replace(t, r"<td .*?style=.*?>(.*?)</td>" => s"<th>\1</th>")
        println( io, t)
    end
end

function make_big_file()
    io = open( "tmp/all_results.html", "w")
    header = """
    <!DOCTYPE html>
    <html>
    <title>Act Now Main Regression Library</title>
    <link rel="stylesheet" href="css/bisite-bootstrap.css"/>
    <body>
    <title>
        <h1>Act Now Main Regression Library</h1>
    </title>
    """
    footer = """
    <footer>

    </footer>
    </body>
    </html>
    """
    println(io, header)

    for (mainvar,exvar) in MAIN_EXPLANDICT
        # exvar = MAIN_EXPLANDICT[Symbol(mainvar)]
        notes1 = """
        <p>
        Results are relative to:
        </p>
        <ul>
            <li>vote next election: Conservative;</li>
            <li>Not Working;</li>
            <li>Female;</li>
            <li><strong>Not</strong> $exvar</li>
        </ul>
        """
        notes2 = """
        Results are Relative to:
        <ul>
            <li>Shown Absolute Gains Argument;</li>
            <li><strong>Not</strong> $exvar.</li>
        </ul>
        """    
        println( io, "<section>")
        println( io, "<h2>Regressions - Main Explanatory Variable: $exvar </h2>")
        println( io, "<h3>Popularity of Each Policy: 1) Full Regression</h3>")
        fn = "tmp/actnow-$(mainvar)-ols.html"
        edit_table( io, fn )
        fnl = "regressions/actnow-$(mainvar)-ols"
        println( io, "<p><a href='$(fnl).txt'>text version</a> | <a href='$(fnl).tex'>latex version</a></p>")
        println( io, notes1 )
        #
        println( io, "<h3>Popularity of Each Policy: 2): Short Regressions</h3>")
        fn = "tmp/actnow-simple-$(mainvar)-ols.html"
        edit_table( io, fn )
        fnl = "regressions/actnow-simple-$(mainvar)-ols"
        println( io, "<p><a href='$(fnl).txt'>text version</a> | <a href='$(fnl).tex'>latex version</a></p>")
        #
        println( io, "<h3>Change in Popularity Of Each Policy: By Argument</h3>")
        fn = "tmp/actnow-change-$(mainvar)-ols.html"
        edit_table( io, fn )    
        println(io, notes2 )    
        fnl = "regressions/actnow-change-$(mainvar)-ols"
        println( io, "<p><a href='$(fnl).txt'>text version</a> | <a href='$(fnl).tex'>latex version</a></p>")
        println( io, "</section>")
    end
    println(io, "<section>")
    println( io, "<h3>Image Gallery</h3>")
    lines = readlines("tmp/image-index.html")
    for l in lines
        println( io, l )
    end
    println(io,"</section>")
    println( io, footer )
    close(io)
end

const POL_COLS = scale_color_manual( :blue,:red,:orange,:green,:grey,:purple )

#=
const BLANK = ggplot() + 
    theme( xticklabelsvisible = false, xgridvisible = false, yticklabelsvisible = false,
        ygridvisible = false, xtickcolor = :transparent, ytickcolor = :transparent, 
        bottomspinevisible = false, topspinevisible = false, rightspinevisible = false, 
        leftspinevisible = false )
=#

"""
Draw our scatter plots with the parties colo[u]red in.
"""
function draw_pol_scat( scatter, title )
    axis = (width = 1200, height = 800, title=title)
    return draw(scatter, 
        scales( Color=(; palette=[:blue,:red,:orange,:green,:grey,:purple] )),
        axis=axis, 
        legend=(; title="Party Vote Last Election"))
end

function draw_density( density, title )
    axis = (width = 1200, height = 800, title=title)
    return draw(density; axis=axis )
end

"""
Drawing all our charts using the marginally less mad AlgebraOfGraphics lib.
"""
function draw_policies2( df::DataFrame, pol1 :: Symbol, pol2 :: Symbol ) :: Tuple
    policy1 = Symbol("$(pol1)_pre")
    policy2 = Symbol("$(pol2)_pre")
    label1 = "Preference for "*pretty( pol1 )
    label2 = "Preference for "*pretty( pol2 )
    title = "$(label1) vs $(label2) (before treatment)"
    vote_label = "Voting Intention (January 2024)"
    # FIXME some neat way of doing this with mapping
    # pol_w = Symbol("$(pol)_weighted")
    # df[:,pol_w] = df[:,policy] .* df.weight
    ddf = data(df)
    
    spec1 = ddf * 
        mapping( 
            policy1=>label1, #:democracy_pre=>"Preference for Democratic Reform",
            policy2=>label2 ) * 
        mapping(  color=:next_election=>vote_label) *
        visual(Scatter)
    
    #=
    layers = 
        mapping( 
            policy1=>label1, #:democracy_pre=>"Democracy",
            policy2=>label2 ) +
        linear() + 
        mapping( color=:next_election=>vote_label) 
    =#

    spec2 = ddf * 
        mapping( 
            policy1=>label1, #:democracy_pre=>"Democracy",
            policy2=>label2 ) * 
        mapping(  color=:next_election=>vote_label) *
        (visual(Scatter) + linear(interval = nothing)) # interval = nothing 

    spec3 = ddf * 
        mapping( 
            policy1=>label1, #:democracy_pre=>"Democracy",
            policy2=>label2 ) * 
        mapping( layout=:next_election=>vote_label) *
        mapping( color=:next_election=>vote_label) * 
        (linear() + visual(Scatter))

    s1 = draw_pol_scat( spec1, title )
    println( "#1")
    s2 = draw_pol_scat( spec2, title )
    println( "#2")
    s3 = draw_pol_scat( spec3, "" )

    f = Figure()
    s1,s2,s3 
end

    # hist = ddf * mapping(pol_w, stack=:next_election, color=:next_election) * histogram(  )
    #=
    hist = ddf * 
        mapping( policy=>label, weights=:weight ) *
        histogram( direction=:x)
        # AlgebraOfGraphics.histogram() # direction = :x ) #AlgebraOfGraphics.density(direction = :x)
    =#

"""
Buggy version using Tidyverse
"""
#=
function draw_policies( df::DataFrame, pol :: Symbol ) :: Tuple
    policy = Symbol("$(pol)_pre")
    label = pretty( pol )
    title = "$(label) vs Democratic Preference (before treatment)"
    # polcolours = parse.(Colorant,[])
    sp = aes( x=:democracy_pre, y=policy )
    scatter = ggplot( df, sp ) + 
        geom_point( @aes(color=last_election ), size=4 ) +
        geom_smooth(; span=0.75, degree=2, npoints=200) +
        labs(x = "Democracy", y = label, title=title ) +
        POL_COLS
    scatter2 = ggplot( df, sp ) + 
        geom_point( @aes(color=last_election ), size=4 ) +
        # geom_smooth() +
        labs(x = "Democracy", y = label, title=title ) +
        POL_COLS
    println( "scatter ")
    democ = ggplot( df) +
        geom_histogram( aes(:democracy_pre )) + 
        theme(xticklabelsvisible = false, xgridvisible = false)
    println( "democ")
    polplot = ggplot(df) +
        geom_histogram( aes( policy ), direction = :x) + 
        theme(yticklabelsvisible = false, ygridvisible = false)
    println( "polplot")
    p = democ + BLANK + polplot + scatter + polplot + 
        plot_layout(ncol = 2, nrow = 2, widths = [3, 1], heights = [1, 2])
    println( "p")
    f = ggplot(df, sp ) + 
        geom_point(size=4) +
        # geom_smooth() +
        labs(x = "Democracy", y = label ) +
        facet_wrap( :last_election ) 
    p, scatter, f
end
=#

#=
for p in POLICIES 
    if p !== :democracy 
        threeplot, scatter, facet = draw_policies( dall, p )
        println( p )
        ggsave( "tmp/actnow-$(p)-multi.svg", threeplot; scale=1,height=800, width=800)
        ggsave( scatter, "tmp/actnow$(p)-scatter.svg" )
        ggsave( facet, "tmp/actnow$(p)-facet.svg" )
    end
end
=#

function make_all_graphs( dall::DataFrame )
    io = open( "tmp/image-index.html","w")
    for p1 in POLICIES 
        println( io, "<section>")
        pp1 = pretty( p1 )
        println( io, "<h3>$pp1</h3>" )
        println( io, "<table class='table'>")
        println( io, "<thead></thead><tbody>")
        for p2 in POLICIES 
            pp2 = pretty( p2 )
            if p1 !== p2 
                cp1,cp2,cp3 = draw_policies2( dall, p1, p2 )
                println( "$p1  $p2" )
                save( "tmp/img/actnow-$(p1)-$(p2)-scatter.svg", cp1 )
                save( "tmp/img/actnow-$(p1)-$(p2)-scatter-linear.svg", cp2 )
                save( "tmp/img/actnow-$(p1)-$(p2)-facet.svg", cp3 )
                save( "tmp/img/actnow-$(p1)-$(p2)-scatter.png", cp1 )
                save( "tmp/img/actnow-$(p1)-$(p2)-scatter-linear.png", cp2 )
                save( "tmp/img/actnow-$(p1)-$(p2)-facet.png", cp3 )
                println( io, "<tr><th>Vs: $pp2</th>")
                println( io, "<td><img src='img/actnow-$(p1)-$(p2)-scatter.svg' width='300' height='300' class='img-thumbnail' alt='...'/></td>")
                println( io, "<td>Combined Scatter Plot</td><td><a href='img/actnow-$(p1)-$(p2)-scatter.png'>PNG</a><td><a href='img/actnow-$(p1)-$(p2)-scatter.svg'>SVG</a> </td>")
                println( io, "<td>Combined Scatter Plot With Regressions</td><td><a href='img/actnow-$(p1)-$(p2)-scatter-linear.png'>PNG</a></td><td><a href='img/actnow-$(p1)-$(p2)-scatter-linear.svg'>SVG</a></td>")
                println( io, "<td>Facet Plot With Regression Lines</a></td><td><a href='img/actnow-$(p1)-$(p2)-facet.png'>PNG</a></td><td><a href='img/actnow-$(p1)-$(p2)-facet.svg'>SVG</a></td>")
                println( io, "</tr>")
            end
            println( io, "</tr>")
        end
        println( io, "</tbody></table>")
        println( io, "</section>")
    end
    close(io)
end

function run_regressions( dall :: DataFrame )
    for mainvar in MAIN_EXPLANVARS
        runregressions( dall, mainvar )
    end
end

# dall = make_dataset()

dall = CSV.File( joinpath( DATA_DIR, "national-w-created-vars.tab")) |> DataFrame 
