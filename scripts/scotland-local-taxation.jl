using ArgCheck
using CairoMakie 
using CSV
using DataFrames
using Format
using Pkg, Pkg.Artifacts
using StatsBase

using ScottishTaxBenefitModel
using .Definitions
using .FRSHouseholdGetter 
using .LocalLevelCalculations
using .ModelHousehold
using .Monitor: Progress
using .Results
using .Runner: do_one_run
using .RunSettings
using .STBParameters
using .TheEqualiser
using .Utils
using .WeightingData

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

const INCREMENT_NAMES = [
    "£100pa Band D Increase",
    "£100pa Band D",
    "1p increase to all income tax bands",
    "£100pa Band D Increase",
    "0.1 increase in rate",
    "£100pa Band D Increase",
    "£100pa Band D Increase"
]

const SYSTEM_NAMES = [
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

"""
With some semi-sensible net zero cost defaults based on the Wales case
"""
function make_parameter_set( code :: Symbol )

    # r = DEFAULT_REFORM_LEVELS[
    #    Symbol.(DEFAULT_REFORM_LEVELS.code) .== code,:][1,:]
    return make_parameter_set(;
        local_income_tax = 10.0, # r.local_income_tax,
        fairer_bands_band_d = 0.0, # r.fairer_bands_band_d,
        proportional_property_tax = 0.8, # r.proportional_property_tax,
        revalued_housing_band_d = -700.0, # r.revalued_housing_band_d,
        revalued_housing_band_d_w_fairer_bands = -1000.0, # r.revalued_housing_band_d_w_fairer_bands,
        code = code )
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


function get_base_cost(  settings :: Settings,
    base_sys :: TaxBenefitSystem ) :: Real
    frames = do_one_run( settings, [base_sys], obs )        
    settings.poverty_line = make_poverty_line( frames.hh[1], settings )
    pc_frames = summarise_frames!(frames, settings)
    base_cost = pc_frames.income_summary[1][1,:net_cost]
    return base_cost
end

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

    base_cost = get_base_cost( settings, base_sys )
        
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

# do_local_sim()
function how_we_doing_fmt(val, row, col )
    if col == 1 # name col
       return val
    end
    return fmt(val/1000.0)
end

function gl_fmt(val, row, col )
    if col == 1 # name col
        if typeof(val) <: AbstractFloat
            return Format.format(val, precision=0)
        else 
            return pretty("$val")
        end
    end
    return fmt(val)
end

function headline_fmt(val, row, col )
    if col == 1
       return val
    elseif col in (2,4)
       return Format.format(val, precision=2)
    end 
    return fmt(val)
end

function changes_to_table( base::Dict, changed::Dict )
    tables = []
    for sys in 1:7
        codes=copy(CTLEVELS.code) # Symbol.(CTLEVELS.code)
        push!( codes, "Total" ) # Symbol(""))
        names=copy(CTLEVELS.name)
        println( "names=$names")
        push!(names,"Total")
        d = DataFrame( 
            name=names, 
            code=codes, 
            ct_change = zeros(23), 
            ctb_change = zeros(23),
            net_change = zeros(23) )  
        
        net_total = 0.0      
        ctb_total = 0.0
        ct_total = 0.0
        for code in CCODES
            scode = String(code) ## FIXME fix base to symbol
            println( "looking for code $scode")
            if sys == 3 ## income tax
                ct_change = changed[scode].income_summary[sys][1,:income_tax] - 
                    base[scode].income_summary[sys][1,:income_tax]
            else
                ct_change = changed[scode].income_summary[sys][1,:local_taxes] - 
                    base[scode].income_summary[sys][1,:local_taxes]
            end
            ctb_change = changed[scode].income_summary[sys][1,:council_tax_benefit] - 
                base[scode].income_summary[sys][1,:council_tax_benefit]
            net_change = ct_change - ctb_change
            net_total += net_change
            ctb_total += ctb_change
            ct_total += ct_change
            d[(d.code.==scode),:ct_change] .= ct_change
            d[(d.code.==scode),:ctb_change] .= ctb_change
            d[(d.code.==scode),:net_change] .= net_change
        end
        d[23,:ct_change] = ct_total
        d[23,:ctb_change] = ctb_total
        d[23,:net_change] = net_total
        push!(tables, d)
    end
    tables
end


function write_main_tables( mainres :: NamedTuple, lares :: Dict, lares_incr :: Dict )
    open("../WalesTaxation/output/main_tables.md","w") do outfile
        println( outfile, "\n\n### Accuracy: Modelled Net Council Tax vs Actual \n£000s pa\n")
        pretty_table( outfile,
            DEFAULT_REFORM_LEVELS[!,[:name,:actual_revenues,:modelled_ct,:modelled_ctb,:net_modelled]],
            formatters=how_we_doing_fmt, 
            tf = tf_markdown )

        println( outfile, "\n\n### Baseline reform levels\n")
        pretty_table( outfile,
            DEFAULT_REFORM_LEVELS[!,
                [:name,
                :local_income_tax,
                :fairer_bands_band_d,
                :proportional_property_tax,
                :revalued_housing_band_d,
                :revalued_housing_band_d_w_fairer_bands]],
            formatters=headline_fmt, tf = tf_markdown )
        change_frames = changes_to_table( lares, lares_incr )
        for sysno in 1:7
            println( outfile, "\n\n## $(SYSTEM_NAMES[sysno])\n")
            println( outfile, "### Gainers and Losers\n" )
            println( outfile, "\n####  By Tenure  \n")
            pretty_table( outfile, mainres.gain_lose[sysno].ten_gl, formatters=gl_fmt, tf = tf_markdown )
            println( outfile, "\n\n#### By Decile\n")
            pretty_table( outfile, mainres.gain_lose[sysno].dec_gl, formatters=gl_fmt, tf = tf_markdown )
            println( outfile, "\n\n#### By Number of Children\n")
            pretty_table( outfile, mainres.gain_lose[sysno].children_gl, formatters=gl_fmt, tf = tf_markdown )
            println( outfile, "\n\n#### By Number of People \n")
            pretty_table( outfile, mainres.gain_lose[sysno].hhtype_gl, formatters=gl_fmt, tf = tf_markdown )
            println( outfile, "\n\n### Effect of $(INCREMENT_NAMES[sysno]). \n£000s pa\n")
            pretty_table( outfile, change_frames[sysno][!,[:name, :ct_change,:ctb_change,:net_change ]], formatters=how_we_doing_fmt, tf = tf_markdown )
        end
    end # file open
end

# prettytable( df; formatters=countfmt, tf = tf_markdown )

function do_everything()
    pc_frames=JLD2.load("all_las_frames.jld2")
    pc_results = JLD2.load( "all_las_results.jld2")
    # pc_frames, pc_results = calculate_local()
    overall_results = do_all( pc_frames, do_gain_lose=true )
    # res_incr = calculate_local( incremented = true )
    pc_frames_incr = JLD2.load("all_las_frames-incremened.jld2")
    pc_results_incr = JLD2.load("all_las_results-incremened.jld2")
    write_main_tables( overall_results, pc_results, pc_results_incr )
    analyse_all( overall_results, pc_results )

end