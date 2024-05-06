using CSV,DataFrames,Tidier,StatsBas,GLM,RegressionTables

buf=loadfrs( 2021, "benunit" )

wash = loaddf( "/mnt/data/was/UKDA-7215-tab/tab/", 2021, "was_round_7_hhold_eul_march_2022" )

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
Mean:           35423.728518
Std. Deviation: 103429.012582
Minimum:        0.000000
1st Quartile:   0.000000
Median:         3481.669613
3rd Quartile:   20000.000000
Maximum:        1109802.991556

## WAS Financial Wealth (positives only)

julia> summarystats( washf.financial_wealth )
Summary Stats:
Length:         14306
Missing Count:  0
Mean:           105456.663263
Std. Deviation: 164508.676369
Minimum:        1.000000
1st Quartile:   7000.000000
Median:         36130.500000
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