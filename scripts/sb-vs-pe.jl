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
pe_hhlds.uidstr = hash.(
    string.(pe_hhlds.council_tax_band__2022).*"-".*
    string.(pe_hhlds.corporate_wealth__2022).*"-".*
    string.(pe_hhlds.main_residence_value__2022).*"-".*
    string.(pe_hhlds.domestic_energy_consumption__2022).*
    string.(pe_hhlds.housing_service_charges__2022).*"-".*
    string.(pe_hhlds.water_and_sewerage_charges__2022).*"-".*
    string.(pe_hhlds.mortgage_interest_repayment__2022).*"-".*
    string.(pe_hhlds.mortgage_capital_repayment__2022).*"-".*
    string.(pe_hhlds.council_tax__2022).*"-".*
    string.(pe_hhlds.region__2022))


for n in names( pe_hhlds )
    println(n)
end

for n in names( pe_pers )
    println(n)
end

for n in names( pe_bus )
    println(n)
end


# hhlds is repeated for each person with no index I can see, so ....
pe_pers.uidstr = hash.(
    string.(pe_pers.age__2022).*"-".*
    string.(pe_pers.childcare_expenses__2022).*"-".*
    string.(pe_pers.employment_income_before_lsr__2022).*"-".*
    string.(pe_pers.miscellaneous_income__2022).*"-".*
    string.(pe_pers.private_transfer_income__2022).*"-".*
    string.(pe_pers.lump_sum_income__2022).*"-".*
    string.(pe_pers.maintenance_income__2022).*"-".*        
    string.(pe_pers.employer_pension_contributions__2022).*
    string.(pe_pers.is_benunit_head__2022).*"-".*
    string.(pe_pers.self_employment_income__2022))

#=

point me to code that derives these records
no actual output 

records:  214,308

hhlds: 24,449
pers: 43,871 distinct records 214,308
derivation from FRS/WAS ... 
interview year/weight
uprated? fixed for non-response 

16364

=#
