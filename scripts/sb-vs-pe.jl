using CSV,DataFrames

using ScottishTaxBenefitModel 
using .Definitions
using .FRSHouseholdGetter
using .ModelHousehold
using .RunSettings
using .Utils


settings = Settings()
settings.num_households, settings.num_people = 
    FRSHouseholdGetter.initialise( settings; reset=false )

SB_DIR = RunSettings.get_data_artifact(settings)
sb_hhlds = CSV.File( joinpath( SB_DIR, "households.tab" ); delim='\t') |> DataFrame 
sb_pers = CSV.File( joinpath( SB_DIR, "people.tab" ); delim='\t') |> DataFrame 

PE_DIR="/mnt/data/PolicyEngine/data/uk-data/"
pe_hhlds = CSV.File( joinpath( PE_DIR, "household.csv" ); delim=',') |> DataFrame 
pe_bus = CSV.File( joinpath( PE_DIR, "benunit.csv" ); delim=',') |> DataFrame 
pe_pers = CSV.File( joinpath( PE_DIR, "person.csv" ); delim=',') |> DataFrame 

# hhlds is repeated for each person with no index I can see, so ....
pe_hhlds.uidstr = hash.(string.(pe_hhlds.council_tax_band__2022).*"-".*string.(pe_hhlds.corporate_wealth__2022).*"-".*string.(pe_hhlds.main_residence_value__2022).*"-".*string.(pe_hhlds.domestic_energy_consumption__2022))
