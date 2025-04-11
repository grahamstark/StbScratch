# redwall analysis, but just for haters of the transport policy

include("actnow-common.jl")
# USED_POLICIES = [:transport]
# USED_ATTITUDES = [:Haters]
include( "redwall.jl")

# 
dall, M_pre, data_pre, prediction_pre, M_change, data_change, prediction_change = load_dall_v4()
# hate transport polcy pre or post subset
tranhates = dall[(dall.transport_pre .< 30) .| (dall.transport_post .< 30), :]
# rerun the analysis 

tranhates.probability_weight = ProbabilityWeights(tranhates.weight./sum(tranhates.weight))
make_and_print_summarystats( tranhates )
run_regressions( tranhates )
make_all_graphs( tranhates )
make_big_file_by_policy()