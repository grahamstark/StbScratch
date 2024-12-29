using DataFrames
using CSV
using Format
using CairoMakie 
using ArgCheck
using Pkg, Pkg.Artifacts

using ScottishTaxBenefitModel
using .RunSettings
using .FRSHouseholdGetter 
using .STBParameters
using .ModelHousehold
using .LocalLevelCalculations: apply_size_criteria, apply_rent_restrictions,
    make_la_to_brma_map, LA_BRMA_MAP, lookup, apply_rent_restrictions, calc_council_tax
using .WeightingData: LA_NAMES, LA_CODES


PROGRESSIVE_RELATIVITIES = Dict{CT_Band,Float64}(
    # halved below, doubled above
    Band_A=>120/360,
    Band_B=>140/360,
    Band_C=>160/360,
    Band_D=>360/360,
    Band_E=>946/360,
    Band_F=>1170/360,                                                                      
    Band_G=>1410/360,
    Band_H=>1764/360,
    # Band_I=>1680/360,
    Household_not_valued_separately => 1.0 ) 

function get_system( ; year = 2024 ):: TaxBenefitSystem
@argcheck year == 2024
    sys = get_default_system_for_fin_year( year; scotland=true )
    return sys
end


function setct!( sys, value )
    for k in eachindex(sys.loctax.ct.band_d)
        sys.loctax.ct.band_d[k] = value
    end
end


INCREMENT_NAMES = [
    "£100pa Band D Increase",
    "£100pa Band D",
    "1p increase to all income tax bands",
    "£100pa Band D Increase",
    "0.1 increase in rate",
    "£100pa Band D Increase",
    "£100pa Band D Increase"
]

SYSTEM_NAMES = [
    "Current System", 
    "CT Incidence",
    "Local Income Tax",
    "Progressive Bands", 
    "Proportional Property Tax",
    "Council Tax With Revalued House Prices and compensating band D cuts", 
    "Council Tax With Revalued House Prices & Fairer Bands" ]

function fmt(v::Number) 
    return Format.format(v, commas=true, precision=0)
end



function make_parameter_set(;
    local_income_tax :: Real, 
    fairer_bands_band_d :: Real,  
    proportional_property_tax :: Real,
    revalued_housing_band_d :: Real,
    revalued_housing_band_d_w_fairer_bands :: Real,
    ccode :: Symbol )

    base_sys = get_system(year=2024)

    no_ct_sys = deepcopy( base_sys )
    no_ct_sys.loctax.ct.abolished = true
    setct!( no_ct_sys, 0.0 )
    
    local_it_sys = deepcopy( no_ct_sys )
    local_it_sys.it.non_savings_rates .+= local_income_tax/100.0

    progressive_ct_sys = deepcopy( base_sys )
    progressive_ct_sys.loctax.ct.relativities = PROGRESSIVE_RELATIVITIES
    progressive_ct_sys.loctax.ct.band_d[ccode] += fairer_bands_band_d / WEEKS_PER_YEAR

    ppt_sys = deepcopy(no_ct_sys)
    ppt_sys.loctax.ct.abolished = true        
    ppt_sys.loctax.ppt.abolished = false
    ppt_sys.loctax.ppt.rate = proportional_property_tax/(100.0*WEEKS_PER_YEAR)
    
    revalued_prices_sys = deepcopy( base_sys )
    revalued_prices_sys.loctax.ct.revalue = true
    revalued_prices_sys.loctax.ct.band_d[ccode] += revalued_housing_band_d/WEEKS_PER_YEAR

    revalued_prices_w_prog_bands_sys = deepcopy( base_sys )
    revalued_prices_w_prog_bands_sys.loctax.ct.revalue = true
    revalued_prices_w_prog_bands_sys.loctax.ct.relativities = PROGRESSIVE_RELATIVITIES
    revalued_prices_w_prog_bands_sys.loctax.ct.band_d[ccode] += revalued_housing_band_d_w_fairer_bands/WEEKS_PER_YEAR
        
    return base_sys,
        no_ct_sys,
        local_it_sys,
        progressive_ct_sys,
        ppt_sys, 
        revalued_prices_sys,
        revalued_prices_w_prog_bands_sys
end

function incremented_params( code :: Symbol, pct_change = false )
    base_sys,
    no_ct_sys,
    local_it_sys,
    progressive_ct_sys,
    ppt_sys, 
    revalued_prices_sys,
    revalued_prices_w_prog_bands_sys = make_parameter_set( code )

    if( ! pct_change )
        base_sys.loctax.ct.band_d[code] += 100.0/WEEKS_PER_YEAR
        # no_ct_sys
        local_it_sys.it.non_savings_rates .+= 0.01
        progressive_ct_sys.loctax.ct.band_d[code] += 100.0/WEEKS_PER_YEAR
        ppt_sys.loctax.ppt.rate  += 0.1/(100*WEEKS_PER_YEAR)
        revalued_prices_sys.loctax.ct.band_d[code] += 100.0/WEEKS_PER_YEAR
        revalued_prices_w_prog_bands_sys.loctax.ct.band_d[code] += 100.0/WEEKS_PER_YEAR
    else
        base_sys.loctax.ct.band_d[code] *= 1.01
        # no_ct_sys
        local_it_sys.it.non_savings_rates *= 1.01
        progressive_ct_sys.loctax.ct.band_d[code] *= 1.01
        ppt_sys.loctax.ppt.rate  += 1.01
        revalued_prices_sys.loctax.ct.band_d[code] *= 1.01
        revalued_prices_w_prog_bands_sys.loctax.ct.band_d[code] *= 1.01
    end
    return base_sys,
        no_ct_sys,
        local_it_sys,
        progressive_ct_sys,
        ppt_sys, 
        revalued_prices_sys,
        revalued_prices_w_prog_bands_sys

end

obs = obs = Observable( Progress(settings.uuid,"",0,0,0,0))

function do_equalising_runs( settings :: Settings )
    global obs 
    # not acually using revenue and total here
    
    no_ct_sys,
    local_it_sys,
    progressive_ct_sys,
    ppt_sys, 
    revalued_prices_sys,
    revalued_prices_w_prog_bands_sys = make_parameter_set( settings.ccode )

    rc = @timed begin
        settings.num_households,settings.num_people,nhh2 = 
            FRSHouseholdGetter.initialise( Settings(), reset=false )
    end   
    FRSHouseholdGetter.restore()
    FRSHouseholdGetter.set_local_weights_and_incomes!( settings; reset=false )

    base_cost = get_base_cost( base_sys )
        
    local_income_tax = equalise( 
        eq_it, 
        local_it_sys, 
        settings, 
        base_cost, 
        obs )
    
    fairer_bands_band_d = equalise( 
            eq_ct_band_d, 
            progressive_ct_sys, 
            settings, 
            base_cost, 
            obs )
    
    proportional_property_tax = equalise( 
        eq_ppt_rate, 
        ppt_sys, 
        settings, 
        base_cost, 
        obs )
    
    revalued_housing_band_d = equalise( 
        eq_ct_band_d, 
        revalued_prices_sys, 
        settings, 
        base_cost, 
        obs )
     
    revalued_housing_band_d_w_fairer_bands = equalise( 
        eq_ct_band_d, 
        revalued_prices_w_prog_bands_sys, 
        settings, 
        base_cost, 
        obs )
    (;  local_income_tax, 
        fairer_bands_band_d, 
        proportional_property_tax, 
        revalued_housing_band_d, 
        revalued_housing_band_d_w_fairer_bands )
end


function do_local_sim()
    settings = Settings()
    settings.do_local_run = true
    aug = "/mnt/data/ScotBen/artifacts/augdata/" # artifact"augdata"
    ld = CSV.File( joinpath( aug, "scottish-la-targets-2024.tab"))|>DataFrame
    rc = @timed begin
        settings.num_households,settings.num_people,nhh2 = 
            FRSHouseholdGetter.initialise( Settings(), reset=false )
    end   
    i = 0 
    for ccode in LA_CODES
        i += 1
        lad = ld[i,:]
        settings.ccode = ccode
        FRSHouseholdGetter.restore()
        FRSHouseholdGetter.set_local_weights_and_incomes!( 
            settings; reset=false )
        num_hhlds = 0.0
        num_ppl  = 0.0
        p2 = sum(ld[i, [:f_0_15, :f_16_24, :f_25_34, :f_35_49, :f_50_64, :f_65plus,
            :m_0_15, :m_16_24, :m_25_34, :m_35_49, :m_50_64, :m_65plus]])
        for hno in 1:settings.num_households
            hh = get_household( hno )
            num_hhlds += hh.weight
            num_ppl += num_people(hh)*hh.weight 
        end
        println( "on $(settings.ccode) name=$(lad.Authority) hhlds = $num_hhlds target=$(lad.total_hhlds) num_people=$(num_ppl) target=$(lad.total_people) target2=$p2")
    end
end

do_local_sim()