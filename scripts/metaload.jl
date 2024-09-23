using Revise
include( "actnow-common.jl")
include( "redwall.jl")
include("changed-since-pandemic.jl")


dall4 =  make_dataset_v4()
dall4, M = load_dall_v4()
dall3 = load_dall_v3()
joined, stacked, skips = joinv3v4( dall3, dall4 )

summaries, counts_joined, counts_all = analyse(joined, dall3, dall4 )
# regs = do_mixed_regressons( stacked )

# oregs = do_delta_regs( joined, skips )

fregs = do_fixed_effects( stacked )
regtable(fregs...;file="tmp/fixed-effect-regs.html",number_regressions=true, stat_below = false, render=HtmlTable(), below_statistic = TStat )
