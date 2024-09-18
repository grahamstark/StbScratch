#
#
#
include("actnow-common.jl")

function load_dall_v3()
    dall = CSV.File( 
        joinpath( DATA_DIR, "Study-3-Full-Data.tab"),
        delim='\t',
        comment="#") |> DataFrame 
    rename!( dall, RENAMES+V3 )
    dropmissing!(dall3,:PROLIFIC_PID)
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
