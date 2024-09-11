#
# Common constants and formatting code for ActNow 
# 

DATA_DIR="/mnt/data/ActNow/Surveys/live/"

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
    "sqrt_phq_8" => "Square Root of PHQ-8 Personal Health Questionnaire Depression Scale",

    ])

const MAIN_EXPLANVARS = Symbol.(collect((keys( MAIN_EXPLANDICT ))))

const POLICIES = [:basic_income, :green_nd, :utilities, :health, :childcare, :education, :housing, :transport, :democracy, :tax]

const RENAMES_V4 = Dict(
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

const RENAMES_V4_REV = Dict( values(RENAMES_V4) .=> keys(RENAMES_V4))

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

    
const SUMMARY_VARS = ["Age",
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
    "gad_7",
    "phq_8",
    "PC1",
    "PC2",
    "PC3"
    # "Change_in_circumstance"
    ]


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
        "Male" => :dodgerblue4
        "Female" => :deeppink3
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


