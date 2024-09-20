using Revise
include( "actnow-common.jl")
include( "redwall.jl")
include("changed-since-pandemic.jl")

dall4, M = load_dall_v4()
dall3 = load_dall_v3()
joined, stacked = joinv3v4( dall3, dall4 )

stats, counts = summarise(joined)
regs = do_mixed_regressons( stacked )

