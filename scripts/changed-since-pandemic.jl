#
#
#
include("actnow-common.jl")

function create_income( r :: DataFrameRow ) :: Union{Real,Missing}
    i = r.Q13
    if ismissing(i)
        return missing
    end
    # println("i=$i PROLIFIC_PID=$(r.PROLIFIC_PID)")
    m = if r.Q14 == "Month"
        12
    elseif r.Q14 == "Week"
        52
    elseif r.Q14 == "Year"
        1
    else
        @assert false "unknown $(r.Q14)"
    end
    # uprated from FEB 2022 to Jan 2024 for comparability with V4 survey
    i * m * CPI_DELTA_FEB_22_JAN_24
end

function incomes_in_range( r :: DataFrameRow )
    if (r.HH_Net_Income_PA <= 0) || (r.HH_Net_Income_PA_1 <= 0)
        return false
    else
        rat = r.HH_Net_Income_PA_1/r.HH_Net_Income_PA
        if (r.HH_Net_Income_PA > 1_00_000)||r.HH_Net_Income_PA_1 > 1_000_000
            return false
        elseif (rat > 3) || (rat < (1/3))
            return false
        end
    end
    return true
end

function load_dall_v3()
    dall3 = CSV.File( 
        joinpath( DATA_DIR, "Study-3-Full-Data.tab"),
        delim='\t',
        comment="#") |> DataFrame 
    dall3 = dall3[dall3.Finished,:]
    dropmissing!(dall3,:PROLIFIC_PID)
    # TODO: income, two aggregate health scores
    # 
    # don't know what's going on ...
    # this is the dataset in Elliot's email of xxx
    # which has the 3 bi variables the main one doesn't have
    # poss I can just use just this one, but it merges pretty well
    dall3_2 = CSV.File( 
        joinpath( DATA_DIR, "survey3", "study.3.data.csv"),
        delim=',',
        comment="#") |> DataFrame 
    dropmissing!(dall3_2,:PROLIFIC_PID)

    dd2 = innerjoin( dall3, dall3_2, on=:PROLIFIC_PID, makeunique=true )
    # idiot check on the merge 
    @assert dd2[dd2.Finished,:StartDate] == dd2[dd2.Finished,:StartDate_1]
    rename!( dd2, RENAMES_V3 )
    # see Elliot's mail of 
    dd2.basic_income_post = coalesce.( 
        dd2.Support_efficiency, 
        dd2.Support_flourishing, 
        dd2.Support_security )
    dropmissing!( dd2, :basic_income_post )    
    dd2.HH_Net_Income_PA = create_income.( eachrow( dd2 ))
    dd2.gad_7 = health_score.(eachrow(dd2), GAD_7...)
    dd2.phq_8 = health_score.(eachrow(dd2), PHQ_8...)
    dd2.sqrt_gad_7 = sqrt.(dd2.gad_7)
    dd2.sqrt_phq_8 = sqrt.(dd2.phq_8)
    dd2.next_election =  recode_party.( dd2.Party_Next_Election, condensed=false )
    dd2.next_election_condensed .= recode_party.( dd2.Party_Next_Election, condensed=true )
    dd2.haters_post = dd2.basic_income_post .< 30 
    dd2.lovers_post = dd2.basic_income_post .> 70
    return dd2
end

function joinv3v4( dall3::DataFrame, dall4::DataFrame)::Tuple
    # tmp hate vars in 4 data
    dall4.haters_post = dall4.basic_income_post .< 30 
    dall4.lovers_post = dall4.basic_income_post .> 70

    dc3 = deepcopy(dall3)
    dc4 = deepcopy(dall4)
    dc3 = dc3[dc3.Finished,:] # 24 examples of not finished
    dc4 = dc4[dc4.Finished,:] # no examples of not finished
    dropmissing!(dc3,:PROLIFIC_PID)
    dropmissing!(dc4,:PROLIFIC_PID)
    joined = innerjoin(
        dc3, dc4;
        on = :PROLIFIC_PID,
        matchmissing = :notequal,
        makeunique = true )
    joined = filter( incomes_in_range, joined )
    threepids = copy(joined.PROLIFIC_PID)
    dc3 = dc3[ in.(dc3.PROLIFIC_PID, ( threepids, )), : ]
    dc4 = dc4[ in.(dc4.PROLIFIC_PID, ( threepids, )), : ]
    #=
    threepids = copy(dc3.PROLIFIC_PID)
    dc3 = dc3[ in.(dc3.PROLIFIC_PID, ( dc4.PROLIFIC_PID, )), : ]
    dc4 = dc4[ in.(dc4.PROLIFIC_PID, ( threepids, )), : ]
    =#
    stacked = vcat( dc3, dc4, cols=:intersect )
    sort!( stacked, [:PROLIFIC_PID,:EndDate])
    @assert size(joined)[1]*2 == size(stacked)[1] "n joined= $(size(joined)[1]*2); n stacked= $(size(stacked)[1])"
    joined, stacked
end

const CORR_TARGETS = [
    "basic_income_post",
    "In_Control_Of_Life",
    "gad_7",
    "phq_8",
    "Ladder", 
    "HH_Net_Income_PA",
    "Age" ] 

  

function pre_post_scatter( 
    joined :: DataFrame,
    var :: String, 
    by  :: String,
    colours :: Dict )
    f = Figure()
    vname = pretty( var )
    vby = pretty( by )
    presym = Symbol( var )
    postsym = Symbol( var* "_1")
    bysym = Symbol( by )
    title = vname 
    subtitle = "Change between Surveys 3 and 4 by $vby"
    ax = Axis(f[1,1],title=title, subtitle=subtitle,
        xlabel="$vname Survey 3",
        ylabel="$vname Survey 4" )
    # FIXME legend
    for (k, colour) in colours
        # hack for Bools 
        label = if k === false
             "No"
        elseif k === true
            "Yes"
        else 
            pretty("$k")
        end
        subset = joined[joined[!,bysym] .== k,:] 
        sc = scatter!( 
            ax,
            subset[!,presym], 
            subset[!,postsym]; 
            color=colour,
            label = pretty(k) )#  joined[!,bysym] )
    end
    Legend(f[1,2], ax )
    return f
end

function analyse( joined :: DataFrame )
    anal = Dict()
    for c in CORR_TARGETS
        presym = Symbol(c)
        postsym = Symbol( "$(c)_1")
        fig_gender = pre_post_scatter( 
            joined, 
            c, 
            "Gender",
            GENDER_MAP )
        fig_pol = pre_post_scatter( 
            joined, 
            c, 
            "next_election",
            POL_MAP )
        s_w3 = summarystats( joined[!,presym] )
        s_w4 = summarystats( joined[!,postsym] )
        corr = cor( joined[ !, presym], joined[ !, postsym] )
        anal[c] = (; fig_gender, fig_pol, s_w3, s_w4, corr )         
    end
    
    counts = (; gender=countmap(joined.Gender_1), pol_w3=countmap(joined.next_election), 
        pol_w4=countmap(joined.next_election_1),
        love_w3=countmap(joined.lovers_post), hate_w3=countmap(joined.haters_post),
        love_w4=countmap(joined.lovers_post_1), hate_w4=countmap(joined.haters_post_1))

    return anal, counts
end

function do_mixed_regressons( stacked :: DataFrame ) :: Tuple
    f1 = @formula(basic_income_post ~ 1 + HH_Net_Income_PA +  At_Risk_of_Destitution + gad_7 + phq_8 + Ladder + 
    (1 + HH_Net_Income_PA + At_Risk_of_Destitution + gad_7 + phq_8 + Ladder | PROLIFIC_PID ))
    fm1 = fit(MixedModel, f1, stacked)
    
    f2 = @formula(basic_income_post ~ 1 + HH_Net_Income_PA +  At_Risk_of_Destitution + gad_7 + phq_8 + Ladder + Age + Gender +
    (1 + HH_Net_Income_PA + At_Risk_of_Destitution + gad_7 + phq_8 + Ladder + Age + Gender | PROLIFIC_PID ))
    fm2 = fit(MixedModel, f2, stacked)

    f3 = @formula(basic_income_post ~ 1 + HH_Net_Income_PA +  At_Risk_of_Destitution + gad_7 + phq_8 + Ladder + Age + Gender + next_election +
    (1 + HH_Net_Income_PA + At_Risk_of_Destitution + gad_7 + phq_8 + Ladder + Age + Gender + next_election | PROLIFIC_PID ))
    fm3 = fit(MixedModel, f3, stacked)

    f4 = @formula(basic_income_post ~ 1 + Ladder + Age + Gender+ next_election +
    (1 + Ladder + Age + Gender + next_election | PROLIFIC_PID ))
    fm4 = fit(MixedModel, f4, stacked)

    fm1, fm2, fm3, fm4
end