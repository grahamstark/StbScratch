module StbScratch

using Reexport
using Revise

@reexport using Markdown
@reexport using CSV
@reexport using GLM
# @reexport using DataFrames
@reexport using RegressionTables
@reexport using StatsBase
@reexport using Statistics
@reexport using StatsModels
# @reexport using CategoricalArrays
@reexport using Tidier
@reexport using StatsKit
@reexport using ScottishTaxBenefitModel
@reexport using Pluto
@reexport using PlutoUI
@reexport using Format
@reexport using DrWatson
@reexport using Cleaner

include( "IncomesBase.jl")
export IncomesBase

# Statistics, StatsModels, Tidier, StatsKit, Pluto, PlutoUI, Format

# Write your package code here.

end
