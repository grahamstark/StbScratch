#
#
#
include("actnow-common.jl")

function load_dall_v3()
    dall3 = CSV.File( 
        joinpath( DATA_DIR, "Study-3-Full-Data.tab"),
        delim='\t',
        comment="#") |> DataFrame 
    dropmissing!(dall3,:PROLIFIC_PID)

    dall3_2 = CSV.File( 
        joinpath( DATA_DIR, "survey3", "study.3.data.csv"),
        delim=',',
        comment="#") |> DataFrame 
    dropmissing!(dall3_2,:PROLIFIC_PID)

    dd2 = innerjoin( dall3, dall3_2, on=:PROLIFIC_PID, makeunique=true )
    rename!( dd2, RENAMES_V3 )

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
    dd2
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
    threepids = copy(dc3.PROLIFIC_PID)
    dc3 = dc3[ in.(dc3.PROLIFIC_PID, ( dc4.PROLIFIC_PID, )), : ]
    dc4 = dc4[ in.(dc4.PROLIFIC_PID, ( threepids, )), : ]
    bothp_stacked = vcat( dc3, dc4, cols=:intersect )
    sort!( bothp_stacked, [:PROLIFIC_PID,:EndDate])
    @assert size(bothp_joined)[1]*2 == size(bothp_stacked)[1] "n joined= $(size(bothp_joined)[1]*2); n stacked= $(size(bothp_stacked)[1])"
    bothp_joined, bothp_stacked
end
