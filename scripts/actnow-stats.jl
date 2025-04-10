using Pkg

Pkg.activate( ".")
# next may take a while 1st time out. Loads all dependencies & compiles them.
Pkg.update()
using Revise
using ActNow
using CSV, DataFrames
#
# to replicate creating the Wave4 dataset with added variables, run the next line
#
# wave4 =  make_dataset_v4()

# This loads the existing wave 4 dataset creates the principal components (M...) - the pca predictions
# are merged with wave4 data.
wave4, M_pre, data_pre, prediction_pre, M_change, data_change, prediction_change = load_dall_v4()

# 
make_and_print_summarystats( wave4 )

run_regressions( wave4, exclude_0s_and_100s = false )
run_regressions( wave4, exclude_0s_and_100s = true )

# println 
make_all_graphs( wave4 )

#=

The next 3 just create big `.html`` files collecting the 
images, summary stats and regressions created above

=#
# writes to `output/all_results_by_policy.html`
make_big_file_by_policy( prefix = "fullsample")
make_big_file_by_policy( prefix = "extremes_excluded" )
   
# writes to `output/all_results_by_explanvar.html`
make_big_file_by_explanvar(prefix = "fullsample")
make_big_file_by_explanvar(prefix = "extremes_excluded")
#
#
# create and write pca analysis 
summarise_pca( wave4, M_pre, "_pre")
summarise_pca( wave4, M_change, "_change")

#
# load wave 3 data
wave3 = load_dall_v3()

#=
create stacked and horizontally joined 
wave3/4 data for fixed effects regressions of changes between w3 and w4
!!!  as a by-prodict adds `in_both_waves` to wave4 - needed for last-minute Path analysis.
=#
joined, stacked, skips = joinv3v4( wave3, wave4 )

#
# optionally, save joined data
#
CSV.write( "$(DATA_DIR)/v3_v4_joined.tab", joined; delim='\t' )
CSV.write( "$(DATA_DIR)/v3_v4_stacked.tab", stacked; delim='\t' )
# CSV.write( "$(DATA_DIR)/national-w-created-vars.tab", wave4; delim='\t'  )

#
# changes between w3 and w4
# 
summaries, counts_joined, counts_all = analyse_w3_w4_changes(
    joined, wave3, wave4 )
# ... written to `output/v3-v4-insert.md`
make_w3_w4_change_page( summaries, counts_joined, counts_all )

# regs = do_mixed_regressons( stacked )

# oregs = do_delta_regs( joined, skips )

#
# dodgy fixed-effects regressions on w3->w4 written to `fixed-effect-regs.html`
#
fregs = do_fixed_effects( stacked )

# this is the data subset that's in both waves.
w4_also_w3 = wave4[wave4.in_both_waves .==1, :]
#
# write regressions for the both-waves sample into `output/regressions_w3_w4`.
# There's no further output for this sample as no-one ever asked for it
# but see the R Path Analysis script which also uses the subsample.
#
run_regressions( w4_also_w3; regdir="regressions_w3_w4" )

#
# 
# 
create_all_crosstabs( index_filename="crosstab-index.md", data=wave4 )