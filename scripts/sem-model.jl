# 
# SEM Model in Julia using Wave 4 Act Now data
# See this for SEM models generally:
# https://stats.oarc.ucla.edu/r/seminars/rsem/
#
# For the Julia implementation, see:  
# https://structuralequationmodels.github.io/StructuralEquationModels.jl/stable/
#
# Dan's R version:
# ./ActNow/Analysis/data processing script.r
# ./ActNow/Analysis/data analysis script.R
# 
include( "actnow-common.jl")

const faith_in_government_vars = [
    :i_Politicians_All_The_Same, :i_Politics_Force_For_Good, :i_Party_In_Government_Doesnt_Matter,
    :i_Politicians_Dont_Care, :i_Politicians_Want_To_Make_Things_Better, :i_Shouldnt_Rely_On_Government ]
    # LogIncomeEquivalised + LadderSES + Satisfactionincome + Managingfinancially
const social_position_vars = [:log_income, :Ladder, :i_Satisfied_With_Income, :i_Managing_Financially]
    #  PHQs + GADs + Control
const distress_vars = [:gad_7, :phq_8, :In_Control_Of_Life]
const sqrt_distress_vars = [:sqrt_gad_7, :sqrt_phq_8, :In_Control_Of_Life]

const observed_vars1 = vcat( [:basic_income_post,:Age], faith_in_government_vars, social_position_vars, distress_vars )

const observed_vars2 = vcat( [:basic_income_post,:Age], faith_in_government_vars, social_position_vars, sqrt_distress_vars )

const latent_vars = [:faith_in_government, :distress, :social_position ]

function do_one_years_SEMS( dall :: DataFrame )
    println( "making graph1")
    actgraph1 = @StenoGraph begin

        # loadings
        faith_in_government → _(faith_in_government_vars)
        social_position → _(social_position_vars)
        distress → _(distress_vars)

        # latent regressions
        faith_in_government → social_position
        distress → social_position
        basic_income_post → social_position + faith_in_government + distress + Age

        # variances
        _(observed_vars1) ↔ _(observed_vars1)
        _(latent_vars) ↔ _(latent_vars)

        # covariances
        faith_in_government ↔ distress
        distress ↔ Age
        faith_in_government ↔ Age
        social_position ↔ Age

    end

    println( "making graph2")
    actgraph2 = @StenoGraph begin

        # loadings
        faith_in_government → _(faith_in_government_vars)
        social_position → _(social_position_vars)
        distress → _(sqrt_distress_vars)

        # latent regressions
        faith_in_government → social_position
        distress → social_position
        basic_income_post → social_position + faith_in_government + distress + Age

        # variances
        _(observed_vars2) ↔ _(observed_vars2)
        _(latent_vars) ↔ _(latent_vars)

        # covariances
        faith_in_government ↔ distress
        distress ↔ Age
        faith_in_government ↔ Age
        social_position ↔ Age

    end


    println( "making partable1")
    partable1 = ParameterTable(
            latent_vars = latent_vars,
            observed_vars = observed_vars1,
            graph = actgraph1 )
    #
    # see: https://structuralequationmodels.github.io/StructuralEquationModels.jl/stable/performance/sorting/           
    sort!(partable1)     
    # note this doesn't converge with the default settings.
    # see for this loss/optimiser, which does converge:
    # https://structuralequationmodels.github.io/StructuralEquationModels.jl/stable/tutorials/construction/outer_constructor/
    #
    println( "making model1")
    model1 = Sem(
            specification = partable1,
            data = dall,
            imply = RAMSymbolic, 
            loss = SemWLS,
            optimizer = SemOptimizerNLopt )

    println( "making fit1")
    model_fit1 = sem_fit(model1)

    println( "making estimate1")
    update_estimate!(partable1, model_fit1)
    sem_summary(partable1)
    sem_summary(model_fit1)
    fit_measures(model_fit1)


    partable2 = ParameterTable(
            latent_vars = latent_vars,
            observed_vars = observed_vars2,
            graph = actgraph2 )
    #
    # see: https://structuralequationmodels.github.io/StructuralEquationModels.jl/stable/performance/sorting/           
    sort!(partable2)     
    # note this doesn't converge with the default settings.
    # see for this loss/optimiser, which does converge:
    # https://structuralequationmodels.github.io/StructuralEquationModels.jl/stable/tutorials/construction/outer_constructor/
    #
    model2 = Sem(
            specification = partable2,
            data = dall,
            imply = RAMSymbolic, 
            loss = SemWLS,
            optimizer = SemOptimizerNLopt )

    model_fit2 = sem_fit(model2)
    update_estimate!(partable2, model_fit2)
    sem_summary(partable2)
    sem_summary(model_fit2)
    fit_measures(model_fit2)

end


function do_all_sems()
    dall3 = load_dall_v3()
    dall3.Managing_Financially =  map_Managing_Financially.( dall3.Managing_Financially )
    for o in union(observed_vars1, observed_vars2)
        println( "on $o")
        dall3[!,o] = extract_number.( dall3[!,o] )
    end
    dall4 = CSV.File( joinpath( DATA_DIR, "national-w-created-vars.tab")) |> DataFrame 
    #
    # Cast weights to StatsBase weights type. Not used ATM.
    #
    dall4.weight = Weights(dall4.weight)
    dall4.probability_weight = ProbabilityWeights(dall4.weight./sum(dall4.weight))
    #
    # this thing only likes numerical values, I think, so...
    for o in union(observed_vars1, observed_vars2)
        dall4[!,o] = extract_number.( dall4[!,o] )
    end

    do_one_years_SEMS( dall4 )
    do_one_years_SEMS( dall3 )
    
end


#=
Attempt 2, see: 
# https://structuralequationmodels.github.io/StructuralEquationModels.jl/stable/tutorials/constraints/constraints/#Using-the-NLopt-backend

using NLopt

# θ[29] + θ[30] - 1 = 0.0
function eq_constraint(θ, gradient)
    if length(gradient) > 0
        gradient .= 0.0
        gradient[29] = 1.0
        gradient[30] = 1.0
    end
    return θ[29] + θ[30] - 1
end

# θ[3] - θ[4] - 0.1 ≤ 0
function ineq_constraint(θ, gradient)
    if length(gradient) > 0
        gradient .= 0.0
        gradient[3] = 1.0
        gradient[4] = -1.0
    end
    θ[3] - θ[4] - 0.1
end


constrained_optimizer = SemOptimizerNLopt(
    algorithm = :AUGLAG,
    options = Dict(:upper_bounds => upper_bounds, :xtol_abs => 1e-4),
    local_algorithm = :LD_LBFGS,
    equality_constraints = NLoptConstraint(;f = eq_constraint, tol = 1e-8),
    inequality_constraints = NLoptConstraint(;f = ineq_constraint, tol = 1e-8),
)

model2 = Sem(
           specification = partable,
           data = dall,
           optimizer = constrained_optimizer )
           
model_fit2 = sem_fit(model2)
update_estimate!(partable, model_fit2)
sem_summary(partable)
sem_summary(model_fit2)

=#