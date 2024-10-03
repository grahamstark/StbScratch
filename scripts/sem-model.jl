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

#
# Functions to convert strings like # 5. Strongly agree" and so on - extract the '5'
#
function extract_number( s :: AbstractString )::Int
    pm = r"([0-9])\.(.*)" 
    # score each 0..4 
    m = match( pm, s )
    tl = parse(Int, m[1])-1
    return tl
end

function extract_number( x :: Number )::Number
    x
end


dall = CSV.File( joinpath( DATA_DIR, "national-w-created-vars.tab")) |> DataFrame 
#
# Cast weights to StatsBase weights type. Not used ATM.
#
dall.weight = Weights(dall.weight)
dall.probability_weight = ProbabilityWeights(dall.weight./sum(dall.weight))


const faith_in_government_vars = [
    :Politicians_All_The_Same, :Politics_Force_For_Good, :Party_In_Government_Doesnt_Matter,
    :Politicians_Dont_Care, :Politicians_Want_To_Make_Things_Better, :Shouldnt_Rely_On_Government ]
    # LogIncomeEquivalised + LadderSES + Satisfactionincome + Managingfinancially
const social_position_vars = [:log_income, :Ladder, :Satisfied_With_Income, :Managing_Financially]
    #  PHQs + GADs + Control
const distress_vars = [:gad_7, :phq_8, :In_Control_Of_Life]

const observed_vars = vcat( [:basic_income_post,:Age], faith_in_government_vars, social_position_vars, distress_vars )

const latent_vars = [:faith_in_government, :distress, :social_position ]

# this thing only likes numerical values, I think, so...
for o in observed_vars
    dall[!,o] = extract_number.( dall[!,o] )
end

actgraph = @StenoGraph begin

    # loadings
    faith_in_government → _(faith_in_government_vars)
    social_position → _(social_position_vars)
    distress → _(distress_vars)

    # latent regressions
    faith_in_government → social_position
    distress → social_position
    basic_income_post → social_position + faith_in_government + distress + Age

    # variances
    _(observed_vars) ↔ _(observed_vars)
    _(latent_vars) ↔ _(latent_vars)

    # covariances
    faith_in_government ↔ distress
    distress ↔ Age
    faith_in_government ↔ Age
    social_position ↔ Age

end

partable = ParameterTable(
           latent_vars = latent_vars,
           observed_vars = observed_vars,
           graph = actgraph)
#
# see: https://structuralequationmodels.github.io/StructuralEquationModels.jl/stable/performance/sorting/           
sort!(partable)     
# note this doesn't converge with the default settings.
# see for this loss/optimiser, which does converge:
# https://structuralequationmodels.github.io/StructuralEquationModels.jl/stable/tutorials/construction/outer_constructor/
#
model1 = Sem(
           specification = partable,
           data = dall,
           imply = RAMSymbolic, 
           loss = SemWLS,
           optimizer = SemOptimizerNLopt )

model_fit1 = sem_fit(model1)
update_estimate!(partable, model_fit1)
sem_summary(partable)
sem_summary(model_fit1)
fit_measures(model_fit1)
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