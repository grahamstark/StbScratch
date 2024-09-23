using Revise
include( "actnow-common.jl")
include( "redwall.jl")
include("changed-since-pandemic.jl")

dall4, M = load_dall_v4()
dall3 = load_dall_v3()
joined, stacked, stats = joinv3v4( dall3, dall4 )

counts, skips = analyse(joined)
# regs = do_mixed_regressons( stacked )

oregs = do_delta_regs( joined, skips )

