using CSV,DataFrames,Tidier,StatsBas,GLM,RegressionTables

buf=loadfrs( 2021, "benunit" )

include( "scripts/utils.jl")
include( "scripts/was_transforms.jl")

wash = loaddf( "/mnt/data/was/UKDA-7215-tab/tab/", 2021, "was_round_7_hhold_eul_march_2022" )
was_add_fields!( wash )

fhw = @chain buf begin
    @group_by sernum
    @filter totcapb3 < 1_000_000
    @summarise hhwealth = sum(totcapb3)
end

washf = @chain wash begin
    @rename financial_wealth=hfinwntr7_sum
    @filter  financial_wealth > 0 && financial_wealth < 1_000_000 
end


mhh = CSV.File( "../ScottishTaxBenefitModel/data/model_households-2015-2021.tab")|>DataFrame

pmhh = @chain mhh begin
    @filter  net_financial_wealth > 0 && net_financial_wealth < 1_000_000 
end

summarystats(fhw.hhwealth)

summarystats( washf.financial_wealth )

summarystats( pmhh.net_financial_wealth )

summarystats( log.(washf.financial_wealth ))

summarystats( log.(pmhh.net_financial_wealth ))



#=

## FRS Financial Wealth 

Summary Stats:
Length:         16108
Missing Count:  0
Mean:           35_423.728518
Std. Deviation: 103429.012582
Minimum:        0.000000
1st Quartile:   0.000000
Median:         3_481.669613
3rd Quartile:   20000.000000
Maximum:        1109802.991556

## WAS Financial Wealth (positives only)

julia> summarystats( washf.financial_wealth )
Summary Stats:
Length:         14306
Missing Count:  0
Mean:           105_456.663263
Std. Deviation: 164508.676369
Minimum:        1.000000
1st Quartile:   7000.000000
Median:         36_130.500000
3rd Quartile:   128000.000000
Maximum:        996000.000000

Median is 10X less!

## Fin Wealth imputed in model

julia> summarystats( pmhh.net_financial_wealth )
Summary Stats:
Length:         94077
Missing Count:  0
Mean:           73888.617958
Std. Deviation: 145047.582769
Minimum:        0.001020
1st Quartile:   3421.032080
Median:         16079.255158
3rd Quartile:   68269.688869
Maximum:        999956.425194

## WAS in logs

julia> summarystats( log.(washf.financial_wealth ))
Summary Stats:
Length:         14306
Missing Count:  0
Mean:           10.127108
Std. Deviation: 2.198699
Minimum:        0.000000
1st Quartile:   8.853665
Median:         10.494893
3rd Quartile:   11.759786
Maximum:        13.811503


## Model in Logs

julia> summarystats( log.(pmhh.net_financial_wealth ))
Summary Stats:
Length:         94077
Missing Count:  0
Mean:           9.551918
Std. Deviation: 2.152403
Minimum:        -6.888106
1st Quartile:   8.137698
Median:         9.685285
3rd Quartile:   11.131221
Maximum:        13.815467

So: 

=#

     
reg_net_physical_1 = lm( @formula( net_physical  ~ 
    scotland + wales + london + # north_west + yorkshire +east_midlands + west_midlands+  east_of_england + south_east + south_west +
    detatched + semi + terraced + purpose_build_flat + #  bedrooms +
    owner + mortgaged +    
    female +
    employee + selfemp + unemployed + student + inactive + sick +   
    age_25_34 + age_35_44 + age_45_54 + age_55_64 +  age_65_74 + age_75_plus + 
    weekly_gross_income + net_financial + managerial + intermediate + 
    num_adults + num_children), wash[(wash.net_physical.>0) .& (wash.net_financial.>0),:] )


reg_net_physical_2 = lm( @formula( net_physical  ~ 
    net_financial), wash[(wash.net_physical.>0) .& (wash.net_financial.>0),:] )
StatsModels.TableRegressionModel{LinearModel{GLM.LmResp{Vector{Float64}}, GLM.DensePredChol{Float64, LinearAlgebra.CholeskyPivoted{Float64, Matrix{Float64}, Vector{Int64}}}}, Matrix{Float64}}

net_physical ~ 1 + net_financial
#=
Coefficients:
────────────────────────────────────────────────────────────────────────────────────────
                Coef.    Std. Error      t  Pr(>|t|)      Lower 95%     Upper 95%
────────────────────────────────────────────────────────────────────────────────────────
(Intercept)    62518.5        756.139       82.68    <1e-99  61036.4        64000.6
net_financial      0.0310737    0.00112607  27.59    <1e-99      0.0288665      0.033281
────────────────────────────────────────────────────────────────────────────────────────
=#

summarystats(wash.net_physical)

#=

Length:         17534
Missing Count:  0
Mean:           63048.826851
Std. Deviation: 85450.473067
Minimum:        2500.000000
1st Quartile:   25000.000000
Median:         47050.000000
3rd Quartile:   77500.000000
Maximum:        5055000.000000

=#

summarystats(wash[wash.net_physical.>0,:net_physical])

#=
mean physical/mean financial 63_048.826851/105_456.663263
=#



#=

Row │ totsav  totcapb3       
       │ Int64   Float64        
───────┼────────────────────────
     1 │      8   29737.6
     2 │      9   70175.0
     3 │     11       0.0
     4 │      1       0.0
     5 │      5    9915.0
     6 │      6    6200.0
     7 │      8       0.0
     8 │      3    1200.0
     9 │      2      20.0
    10 │      5   15600.0
    11 │      8  315000.0
    12 │      6   20000.0
    13 │      9       1.14094e5
    14 │      7   17561.0
    15 │      1       0.0
    16 │      2       0.0
    17 │      6    9230.0
    18 │      5    7000.0
    19 │      2    2154.7
    20 │      2       0.0
    21 │      2       0.0
    22 │      1       0.0
    23 │     -1       0.0
    24 │      4    2000.0
    25 │      3       0.0
    26 │     10  297326.0
    27 │      2       0.0
    28 │      3    2500.0
    29 │      1       0.0
    30 │      1      16.0
    31 │      4    1400.0


totsav 
dataset | year | tables  | variable_name | value |            label            |         enum_value          
---------+------+---------+---------------+-------+-----------------------------+-----------------------------
 frs     | 2020 | benunit | TOTSAV        | 1     | Less than £100              | Less_than_£100
 frs     | 2020 | benunit | TOTSAV        | 2     | From £100 up to £1,500      | From_£100_up_to_£1_500
 frs     | 2020 | benunit | TOTSAV        | 3     | From £1,500 up to £3,000    | From_£1_500_up_to_£3_000
 frs     | 2020 | benunit | TOTSAV        | 4     | From £3,000 up to £6,000    | From_£3_000_up_to_£6_000
 frs     | 2020 | benunit | TOTSAV        | 5     | From £6,000 up to £16,000   | From_£6_000_up_to_£16_000
 frs     | 2020 | benunit | TOTSAV        | 6     | From £16,000 up to £30,000  | From_£16_000_up_to_£30_000
 frs     | 2020 | benunit | TOTSAV        | 7     | From £30,000 up to £50,000  | From_£30_000_up_to_£50_000
 frs     | 2020 | benunit | TOTSAV        | 8     | From £50,000 up to £200,000 | From_£50_000_up_to_£200_000
 frs     | 2020 | benunit | TOTSAV        | 9     | From £200,000 to £500,000   | From_£200_000_to_£500_000
 frs     | 2020 | benunit | TOTSAV        | 10    | Over £500,000               | Over_£500_000
 frs     | 2020 | benunit | TOTSAV        | 11    | Does not wish to say        | Does_not_wish_to_say

=#

## IMPUTED financial captital USING map_totsav

mps = CSV.File( "data/model_people_scotland-2015-2021.tab")|>DataFrame

x=Real[]
for r in eachrow(mps)
    if (! ismissing(r.is_bu_head )) .& (r.is_bu_head == 1)
        push!( x, map_totsav( r.totsav, r.data_year, r.wealth_and_assets, r.onerand ))
    end
end
summarystats(x)

#= WORSE!!!!
Summary Stats:
Length:         19262
Missing Count:  0
Mean:           44053.169573
Std. Deviation: 289117.958589
Minimum:        0.000000
1st Quartile:   0.000000
Median:         2800.500000
3rd Quartile:   21904.250000
Maximum:        13611047.900406
=#

for r in eachrow(mps)
    if (! ismissing(r.is_bu_head )) .& (r.is_bu_head == 1)
        cap = map_totsav(r.totsav,r.data_year,r.wealth_and_assets,r.onerand )
        if cap < r.wealth_and_assets
            println( "totsav = $(r.totsav) datayear = $(r.data_year) cap=$cap frs assets $(r.wealth_and_assets), pid=$(r.pid)")
        end
        push!(x, cap )
    end
end
    
#= using max(cap, frs_assets)
Summary Stats:
Length:         19262
Missing Count:  0
Mean:           51390.755938
Std. Deviation: 322274.026020
Minimum:        0.000000
1st Quartile:   0.000000
Median:         3500.000000
3rd Quartile:   25827.500000
Maximum:        14220994.478282

vs 
Summary Stats:
Length:         16108
Missing Count:  0
Mean:           35_423.728518
Std. Deviation: 103429.012582
Minimum:        0.000000
1st Quartile:   0.000000
Median:         3_481.669613
3rd Quartile:   20000.000000
Maximum:        1109802.991556


=#

