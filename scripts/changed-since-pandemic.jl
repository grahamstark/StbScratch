#
#
#
include("actnow-common.jl")

function create_income( r :: DataFrameRow ) :: Union{Real,Missing}
    i = r.Q13
    if ismissing(i)
        return missing
    end
    # println("i=$i PROLIFIC_PID=$(r.PROLIFIC_PID)")
    m = if r.Q14 == "Month"
        12
    elseif r.Q14 == "Week"
        52
    elseif r.Q14 == "Year"
        1
    else
        @assert false "unknown $(r.Q14)"
    end
    i * m
end

function incomes_in_range( r :: DataFrameRow )
    if (r.HH_Net_Income_PA <= 0) || (r.HH_Net_Income_PA_1 <= 0)
        return false
    else
        rat = r.HH_Net_Income_PA_1/r.HH_Net_Income_PA
        if (r.HH_Net_Income_PA > 1_00_000)||r.HH_Net_Income_PA_1 > 1_000_000
            return false
        elseif (rat > 3) || (rat < (1/3))
            return false
        end
    end
    return true
end

function load_dall_v3()
    dall3 = CSV.File( 
        joinpath( DATA_DIR, "Study-3-Full-Data.tab"),
        delim='\t',
        comment="#") |> DataFrame 
    dropmissing!(dall3,:PROLIFIC_PID)
    # TODO: income, two aggregate health scores
    # 
    # don't know what's going on ...
    # this is the dataset in Elliot's email of xxx
    # which has the 3 bi variables the main one doesn't have
    # poss I can just use just this one, but it merges pretty well
    dall3_2 = CSV.File( 
        joinpath( DATA_DIR, "survey3", "study.3.data.csv"),
        delim=',',
        comment="#") |> DataFrame 
    dropmissing!(dall3_2,:PROLIFIC_PID)
    dd2 = innerjoin( dall3, dall3_2, on=:PROLIFIC_PID, makeunique=true )
    # idiot check on the merge 
    @assert dd2[dd2.Finished,:StartDate] == dd2[dd2.Finished,:StartDate_1]
    rename!( dd2, RENAMES_V3 )
    # see Elliot's mail of 
    dd2.basic_income_post = coalesce.( 
        dd2.Support_efficiency, 
        dd2.Support_flourishing, 
        dd2.Support_security )
    dd2.HH_Net_Income_PA = create_income.( eachrow( dd2 ))
    
    #
    # Cast weights to StatsBase weights type.
    #
    #=
    dall.weight = Weights(dall.weight)
    dall.probability_weight = ProbabilityWeights(dall.weight./sum(dall.weight))
    # factor cols
    M, data, prediction = do_basic_pca(dall)
    dall = hcat( dall, prediction )
    dall, M
    =#
    return dd2
end


function joinv3v4( dall3::DataFrame, dall4::DataFrame)::Tuple
    dc3 = deepcopy(dall3)
    dc4 = deepcopy(dall4)
    dc3 = dc3[dc3.Finished,:] # 24 examples of not finished
    dc4 = dc4[dc4.Finished,:] # no examples of not finished
    dropmissing!(dc3,:PROLIFIC_PID)
    dropmissing!(dc4,:PROLIFIC_PID)
    bothp_joined = innerjoin(
        dc3, dc4;
        on = :PROLIFIC_PID,
        matchmissing = :notequal,
        makeunique = true )
    bothp_joined = filter( incomes_in_range, bothp_joined )
    threepids = copy(bothp_joined.PROLIFIC_PID)
    dc3 = dc3[ in.(dc3.PROLIFIC_PID, ( threepids, )), : ]
    dc4 = dc4[ in.(dc4.PROLIFIC_PID, ( threepids, )), : ]
    #=
    threepids = copy(dc3.PROLIFIC_PID)
    dc3 = dc3[ in.(dc3.PROLIFIC_PID, ( dc4.PROLIFIC_PID, )), : ]
    dc4 = dc4[ in.(dc4.PROLIFIC_PID, ( threepids, )), : ]
    =#
    bothp_stacked = vcat( dc3, dc4, cols=:intersect )
    sort!( bothp_stacked, [:PROLIFIC_PID,:EndDate])
    @assert size(bothp_joined)[1]*2 == size(bothp_stacked)[1] "n joined= $(size(bothp_joined)[1]*2); n stacked= $(size(bothp_stacked)[1])"
    bothp_joined, bothp_stacked
end

const CORR_TARGETS = [
    :General_Health, :General_Health_1, 
    :Little_interest_in_things, :Little_interest_in_things_1, 
    :Depressed, :Depressed_1, 
    :Trouble_Sleeping, :Trouble_Sleeping_1, 
    :No_Energy, :No_Energy_1, 
    :Poor_Appetite, :Poor_Appetite_1, 
    :Feeling_Failure, :Feeling_Failure_1, 
    :Trouble_Concentrating, :Trouble_Concentrating_1, 
    :More_Restless_Than_Usual, :More_Restless_Than_Usual_1, 
    :Anxious, :Anxious_1, 
    :Uncontrolled_Worry, :Uncontrolled_Worry_1, 
    :Worrying_To_Much, :Worrying_To_Much_1, 
    :Trouble_Relaxing, :Trouble_Relaxing_1, 
    :Restless_Cant_Sit_Still, :Restless_Cant_Sit_Still_1, 
    :Easily_Annoyed, :Easily_Annoyed_1, 
    :Afraid, :Afraid_1, 
    :In_Control_Of_Life, :In_Control_Of_Life_1, 
    :At_Risk_of_Destitution, :At_Risk_of_Destitution_1, 
    :Managing_Financially, :Managing_Financially_1, 
    :Satisfied_With_Income, :Satisfied_With_Income_1, 
    :Ladder, :Ladder_1, 
    :Age, :Age_1, 
    :Gender, :Gender_1, 
    :Gender_Other, :Gender_Other_1, 
    :basic_income_post, :basic_income_post_1]


function analyse( bothp_joined :: DataFrame )
    f = Figure()
    ax = Axis(f[1,1],title="Nominal Income Change", xlabel="Income Wave 3",ylabel="Income Wave 4")
    scatter!( ax, bothp_joined.HH_Net_Income_PA, bothp_joined.HH_Net_Income_PA_1; color=bothp_joined.not_managing_financially )
    # FIXME legend 
    p1 = scatter( 
        bothp_joined.basic_income_post, 
        bothp_joined.basic_income_post_1; 
        color=bothp_joined.not_managing_financially )
    s3 = summarystats( bothp_joined.basic_income_post )
    s4 = summarystats( bothp_joined.basic_income_post_1 )
    correlations
    f, s3, s4
end