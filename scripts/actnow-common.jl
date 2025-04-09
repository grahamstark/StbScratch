#
# Common constants and formatting code for ActNow 
# 
# FIXME check which graphics are actually used here
using 
    AlgebraOfGraphics,
    CairoMakie,
    CategoricalArrays,
    ColorSchemes,
    CSV,
    DataFrames,
    FixedEffectModels,
    Format,
    GLM,
    HypothesisTests,
    Makie,
    MixedModels,
    MultivariateStats,
    PrettyTables,
    RegressionTables,
    StatsBase,
    StructuralEquationModels,
    SurveyDataWeighting,
    Tidier
    
using ScottishTaxBenefitModel
using .Utils 
    

# const DATA_DIR="/mnt/data/ActNow/Surveys/live/"
# FIXME TEMP!!!
const DATA_DIR="/home/graham_s/julia/vw/StbScratch/data/"

# FIXME use this consistently
const TREATMENT_TYPESDICT = Dict([
    "relgains" => "Relative Gains", 
    "security" => "Security", 
    "absgains" => "Absolute Gains", 
    "other_argument" => "Other Argument"])

const TREATMENT_TYPES = collect((keys( TREATMENT_TYPESDICT )))

const MAIN_EXPLANDICT = Dict([
    # "x" => "No Main Expanatory Variable",
    "destitute"=>"At Risk Of Destitution (Q66.9_1 is 70 and over)", 
    "poorhealth" => "In Poor Health (Q66.13 is 'Bad' or 'Very Bad')",
    "unsatisfied_with_income" => "Unsatisfied with Income (Q66.11 in 1,2,3)",
    "Owner_Occupier" => "Owner Occupier, inc. with a Mortgage (Q66.8=yes)", 
    "down_the_ladder" => "Low Life Satisfaction (Q66.12 - Life Ladder in 1..4)",
    "not_managing_financially" => "Not Managing Well Financially (Q66.10 in 4,5)",
    "At_Risk_of_Destitution" => "Risk Of Destitution (Q66.9_1)",
    "General_Health" => "General Health (Q66.13)",    
    "Ladder" => "Life Ladder (Q66.12)",
    "Satisfied_With_Income"=>"Satsified with Income (Q66.11)",
    "Managing_Financially"=>"Managing Finacially (Q66.10)",
    "gad_7" => "GAD-7 Generalized Anxiety Disorder 7",
    "phq_8" => "PHQ-8 Personal Health Questionnaire Depression Scale",
    "sqrt_gad_7" => "Square Root of GAD-7 Generalized Anxiety Disorder 7",
    "sqrt_phq_8" => "Square Root of PHQ-8 Personal Health Questionnaire Depression Scale"])

const MAIN_EXPLANVARS = Symbol.(collect((keys( MAIN_EXPLANDICT ))))
const ATTITUDES = ["All","Lovers","Haters"]
const POLICIES = [:basic_income, :green_nd, :utilities, :health, :childcare, :education, :housing, :transport, :democracy, :tax]
const POLICY_LABELS = Dict([:basic_income=>"Basic Income", 
    :green_nd=>"Green New Deal", 
    :utilities=>"Utilities", 
    :health=>"Health", 
    :childcare=>"Childcare", 
    :education=>"Education", 
    :housing=>"Housing", 
    :transport=>"Transport", 
    :democracy=>"Democracy", 
    :tax=>"Taxation"])

USED_POLICIES = copy( POLICIES )
USED_ATTITUDES = copy(ATTITUDES)

const RENAMES_V4 = Dict(
    "Q65.2_1"=>"overall_post",
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
    "Q66.24_2"=>"Politics_Force_For_Good",
    "Q66.24_3"=>"Party_In_Government_Doesnt_Matter",
    "Q66.24_4"=>"Politicians_Dont_Care",
    "Q66.24_5"=>"Politicians_Want_To_Make_Things_Better",
    "Q66.24_6"=>"Shouldnt_Rely_On_Government" )

const RENAMES_V4_REV = Dict( values(RENAMES_V4) .=> keys(RENAMES_V4))

#=
Depression PHQ-8 total score	Q9.1_1 through Q9.1_8	Q9.1_1 through Q9.1_8
Anxiety GAD-7 total score	Q25_1 through Q25_7	Q66.15_1 through Q66.15_7
Risk of destitution 0-100 extremely low risk to extremely high risk	Q30_1	Q66.9_1
Control of life 0-100 completely out of control to completely in control	Q29_1	Q66.17_1
Age	Q51	Q66_2
Satisfaction with income  1 = 'Completely Dissatisfied' to 7 = 'Completely Satisfied'	Q34	Q66.11
Managing financially 1-5 scale (comfortable to struggling)	Q33	Q66_10
MacArthur Scale of Subjective Social Status 1-10 family worst off to best off	Q37 ('where you think you stand at this time in your life relative to other people in the United Kingdom')	Q66.12 (family in British society)
Faith/cynicism in government (some statements go from cynicism to faith and some faith to cynicism so need to be standardised)	Q40_1 through Q40_6	Q66.24_1 through Q66.24_6
Party voting intention at the next election	Q56	Q66.23

=#
const RENAMES_V3 = Dict([
    "Q9.1_1"=>"Little_interest_in_things",
    "Q9.1_2"=>"Depressed",
    "Q9.1_3"=>"Trouble_Sleeping",
    "Q9.1_4"=>"No_Energy",
    "Q9.1_5"=>"Poor_Appetite",
    "Q9.1_6"=>"Feeling_Failure",
    "Q9.1_7"=>"Trouble_Concentrating",
    "Q9.1_8"=>"More_Restless_Than_Usual",
    "Q25_1"=>"Anxious",
    "Q25_2"=>"Uncontrolled_Worry",
    "Q25_3"=>"Worrying_To_Much",
    "Q25_4"=>"Trouble_Relaxing",
    "Q25_5"=>"Restless_Cant_Sit_Still",
    "Q25_6"=>"Easily_Annoyed",
    "Q25_7"=>"Afraid",
    "Q30_1"=>"At_Risk_of_Destitution",
    "Q29_1"=>"In_Control_Of_Life",
    "Q51"=>"Age",
    "Q52"=>"Gender",
    "Q52_3_TEXT"=>"Gender_Other",
    "Q33"=>"Managing_Financially",
    "Q34"=>"Satisfied_With_Income",
    "Q37"=>"Ladder",
    "Q19"=>"General_Health",
    "Q56"=>"Party_Next_Election",
    "Q56_7_TEXT"=>"Party_Next_Election_Other",
    "Q40_1"=>"Politicians_All_The_Same",
    "Q40_2"=>"Politics_Force_For_Good",
    "Q40_3"=>"Party_In_Government_Doesnt_Matter",
    "Q40_4"=>"Politicians_Dont_Care",
    "Q40_5"=>"Politicians_Want_To_Make_Things_Better",
    "Q40_6"=>"Shouldnt_Rely_On_Government" ])

const RENAMES_V3_REV = Dict( values(RENAMES_V3) .=> keys(RENAMES_V3))
#= 
# renaming was dumb
# sum over these for GAD-7 Generalized Anxiety Disorder 7",
  and PHQ-8 Personal Health Questionnaire Depression Scale"
=#
const PHQ_8 = [
    "Anxious",
    "Uncontrolled_Worry",
    "Worrying_To_Much",
    "Trouble_Relaxing",
    "Restless_Cant_Sit_Still",
    "Easily_Annoyed",
    "Afraid" ]

const GAD_7 = [
    "Little_interest_in_things",
    "Depressed",
    "Trouble_Sleeping",
    "No_Energy",
    "Poor_Appetite",
    "Feeling_Failure",
    "Trouble_Concentrating",
    "More_Restless_Than_Usual" ]

const TRUST_POL = [
    "Politicians_All_The_Same",
    "Politics_Force_For_Good",
    "Party_In_Government_Doesnt_Matter",
    "Politicians_Dont_Care",
    "Politicians_Want_To_Make_Things_Better",
    "Shouldnt_Rely_On_Government" ]

"""
return 24 (most) .. 0 least 
"""
function build_trust( r :: DataFrameRow )::Int
    trust = 0
    pm = r"([0-9])\.(.*)" # 5. Strongly agree" and so on - extract the '5'
    for t in TRUST_POL
        # score each 0..4 
        m = match( pm, r[t])
        tl = parse(Int, m[1])-1
        # reverse good ones 
        if t in ["Politics_Force_For_Good","Politicians_Want_To_Make_Things_Better"]
            tl = 4 - tl
        end
        trust += tl 
    end
    return 24-trust # 24 (4x6) is most trusting ... 
end

function lpretty( s :: AbstractString ) :: String
    o = pretty( s )
    v = get(RENAMES_V4_REV,s,"")
    if v == ""
        return o
    end
    return "$v - $o"
end 

function lpretty( s :: Symbol ) :: String
    lpretty(String(s))
end

    
const SUMMARY_VARS = [
    "Any_Argument",
    "Age",
    "Gender",
    # "Gender_Other",
    "Ethnic",
    "Left_Right",
    "last_election",
    "next_election",
    "HH_Net_Income_PA",
    "Employment_Status",
    # "Employment_Status_Other",
    "Owner_Occupier",
    "At_Risk_of_Destitution",
    "Managing_Financially",
    "Satisfied_With_Income",
    "Ladder",
    "General_Health",
    "Little_interest_in_things",
    "Depressed",
    "Trouble_Sleeping",
    "No_Energy",
    "Poor_Appetite",
    "Feeling_Failure",
    "Trouble_Concentrating",
    "More_Restless_Than_Usual",
    "Anxious",
    "Uncontrolled_Worry",
    "Worrying_To_Much",
    "Trouble_Relaxing",
    "Restless_Cant_Sit_Still",
    "Easily_Annoyed",
    "Afraid",
    "Think_About_Future",
    "In_Control_Of_Life",
    "Life_Satisfaction",
    "Politicians_All_The_Same",
    "Politics_Force_For_Good",
    "Party_In_Government_Doesnt_Matter",
    "Politicians_Dont_Care",
    "Politicians_Want_To_Make_Things_Better",
    "Shouldnt_Rely_On_Government",
    "trust_in_politics",
    "gad_7",
    "phq_8"
    # "Change_in_circumstance"
    ]


const DEPLEVELS = [
    "Not at all",
    "Several days",
    "More than half the days",
    "Nearly every day" ]
    
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
form( v :: Number, i, j ) = Format.format(v; precision=2, commas=true )
f2( v :: Number )= Format.format(v; precision=2, commas=true )

"""
Hacky p-values cols in stats tables.
"""
function pform( v :: Any, r, c)
    if ! (typeof( v ) <: Number)
        return form(v,r,c)
    elseif c in [8,18,20]
        s = Format.format(v; precision=4 )
        return "($s)"
    end
    return Format.format(v; precision=2, commas=true )
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


const POL_COLS = scale_color_manual( :blue,:red,:orange,:green,:grey,:purple )

const BOOL_MAP = Dict(
    [
        "Yes" => :darkgreen,
        "No"  => :red
    ]
)

const BOOL_MAP_2 = Dict(
    [
        true => :darkgreen,
        false  => :red
    ]
)

const GENDER_MAP = Dict(
    [
        "Male" => :dodgerblue4,
        "Female" => :deeppink3,
        "Other" => :grey
    ]
)

const ETHNIC_MAP = Dict(
    [
        "Ethnic British" => :grey,
        "Other Ethnic" => :blue
    ]
)

const POL_MAP = Dict([
    "Conservative" => :blue,
    "Labour" => :red,
    "Nat/Green" => :green,
    "LibDem" => :orange,
    "No Vote/DK/Refused" => :lightgrey,
    "Other/Brexit" => :purple])

const PCA_BREAKDOWNS = [:destitute, :not_managing_financially, :last_election,:Owner_Occupier,:Gender, :ethnic_2, ]

function pol_col( party :: AbstractString, map::Dict )::Symbol
    return get(map,string(party),:grey )
end


function health_score( p :: DataFrameRow, keys... )::Union{Int,Missing}

    function map_one( s :: AbstractString )::Int
        findfirst(x->x==s,DEPLEVELS) - 1 
    end

    i = 0
    for k in keys
        if ismissing(p[k])
            return missing
        end
        i += map_one( p[k])
    end
    return i
end


#=
https://www.ons.gov.uk/economy/inflationandpriceindices/datasets/consumerpriceindices

CPI INDEX 00: ALL ITEMS 2015=100
D7BT

Index, base year = 100
18-09-2024
16 October 2024
=#

const CPI_FEB_2022 = 115.8
const CPI_JAN_2024 = 131.5
const CPI_DELTA_FEB_22_JAN_24 = CPI_JAN_2024/CPI_FEB_2022

#=
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

=#

"""
FIXME mess
"""
function recode_party( party :: Union{AbstractString,Missing}; condensed :: Bool ) :: String
    d = if ismissing( party )
        ("No Vote/DK/Refused","Other")
    elseif party in ["Conservative Party"]
        ("Conservative", "Conservative")
    elseif party in ["Green Party", "Plaid Cymru", "Scottish National Party"]
        ("Nat/Green","Other")
    elseif party in ["Labour Party"]
        ("Labour","Labour")
    elseif party in ["Liberal Democrats"]
        ("LibDem","Other")
    elseif party in ["Other (please name below)", "Independent candidate","Brexit Party"]
        ("Other/Brexit","Other")
    else 
        ("No Vote/DK/Refused","Other")
    end
    return condensed ? d[2] : d[1]
end

#=
"An independent candidate"
 "Brexit Party"
 "Conservative Party"
 "Green Party"
 "I will choose not to vote at the next General Election"
 "I will not be eligible to vote " ⋯ 19 bytes ⋯ " Election (i.e. residency etc.)"
 "Labour Party"
 "Liberal Democrats"
 "Other (please name below)"
 "Prefer not to say"
=#

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

function recode_ethnic( ethnic :: AbstractString ) :: String
    return ethnic == "1. English, Welsh, Scottish, Northern Irish or British" ? "Ethnic British" : "Other Ethnic" 
end

function recode_gender( gender :: AbstractString )::String 
    # println("recode gender $gender")
    return gender in ["Male","Female"] ? gender : "Other"
end

function map_Managing_Financially( s :: AbstractString ) :: Int 
    return if s == "Doing alright"
        2
    elseif s == "Finding it quite difficult"
        5
    elseif s == "Finding it very difficult"
        4
    elseif s == "Just about getting by"
        3
    elseif s == "Living comfortably"
        1
    end
end

#
# Functions to convert strings like # 5. Strongly agree" and so on - extract the '5'
#
function extract_number( s :: AbstractString )::Int
    pm = r"([0-9])\.(.*)" 
    # score each 0..4 
    m = match( pm, s )
    tl = parse(Int, m[1])-1
    return tl
end

function extract_number( x :: Number )::Number
    x
end
