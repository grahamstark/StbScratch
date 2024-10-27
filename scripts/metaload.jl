using Revise
includet( "scripts/actnow-common.jl")
includet( "scripts/redwall.jl")
includet("scripts/changed-since-pandemic.jl")
includet("scripts/cellthing-luxor.jl")



dall4 =  make_dataset_v4()
dall4, M_pre, data_pre, prediction_pre, M_change, data_change, prediction_change = load_dall_v4()
dall3 = load_dall_v3()
joined, stacked, skips = joinv3v4( dall3, dall4 )

summaries, counts_joined, counts_all = analyse(joined, dall3, dall4 )
# regs = do_mixed_regressons( stacked )

# oregs = do_delta_regs( joined, skips )

fregs = do_fixed_effects( stacked )
regtable(fregs...;file="tmp/fixed-effect-regs.html",number_regressions=true, stat_below = false, render=HtmlTable(), below_statistic = TStat )
make_md_page( summaries, counts_joined, counts_all )

