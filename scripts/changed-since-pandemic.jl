#
#
#
include("actnow-common.jl")

function create_income( r :: DataFrameRow; uprate = true  ) :: Union{Real,Missing}
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
    inc = i * m / 1000.0
    if uprate
        inc *= CPI_DELTA_FEB_22_JAN_24
    end
    inc
end

function incomes_in_range( r :: DataFrameRow ) :: Bool
    if (r.HH_Net_Income_PA <= 0) || (r.HH_Net_Income_PA_1 <= 0)
        return false
    else
        rat = r.HH_Net_Income_PA_1/r.HH_Net_Income_PA
        if (r.HH_Net_Income_PA > 1_000)||r.HH_Net_Income_PA_1 > 1_000
            return false
        elseif (rat > 3) || (rat < (1/3))
            return false
        end
    end
    return true
end

function age_and_sex_change_sensible( r :: DataFrameRow ) :: Bool
    if ! (r.Age_v4 - r.Age_v3) in 1:2 
        return false
    elseif r.Gender_v4 !== r.Gender_v3
        return false
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
    dd2.HH_Net_Income_PA = create_income.( eachrow( dd2 ); uprate=true)
    dd2.gad_7 = health_score.(eachrow(dd2), GAD_7...)
    dd2.phq_8 = health_score.(eachrow(dd2), PHQ_8...)
    dd2.sqrt_gad_7 = sqrt.(dd2.gad_7)
    dd2.sqrt_phq_8 = sqrt.(dd2.phq_8)
    dd2.next_election =  recode_party.( dd2.Party_Next_Election, condensed=false )
    dd2.next_election_condensed .= recode_party.( dd2.Party_Next_Election, condensed=true )
    dd2.haters_post = dd2.basic_income_post .< 30 
    dd2.lovers_post = dd2.basic_income_post .> 70
    dd2.zeros_post = dd2.basic_income_post .== 0
    dd2.hundreds_post = dd2.basic_income_post .== 100
    dd2.Gender = recode_gender.( dd2.Gender )
    dd2.trust_in_politics = build_trust.( eachrow( dd2 ))
    dd2.log_income = log.(dd2.HH_Net_Income_PA)
    return dd2
end

const CORR_TARGETS = [
    "basic_income_post",
    "At_Risk_of_Destitution",
    "In_Control_Of_Life",
    "gad_7",
    "phq_8",
    "Ladder", 
    "HH_Net_Income_PA",
    "trust_in_politics",
    "Age" ] 

function joinv3v4( dall3::DataFrame, dall4::DataFrame)::Tuple
    # tmp hate vars in 4 data
    dall4.haters_post = dall4.basic_income_post .< 30 
    dall4.lovers_post = dall4.basic_income_post .> 70
    dall4.zeros_post = dall4.basic_income_post .== 0
    dall4.hundreds_post = dall4.basic_income_post .== 100

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
    # cut down joined to just shared things, rename stuff to v3/v4
    nms = names(stacked)
    nm2 = copy( nms ) .* "_1"
    allnames = vcat(nms,nm2)
    deleteat!(allnames, findall(x->x=="PROLIFIC_PID_1",allnames))
    select!( joined, allnames ... )
    for n in allnames
        if n == "PROLIFIC_PID"
            ;
        else
            m = match( r"(.*)_1", n )
            if isnothing(m)
                rename!( joined, n => n*"_v3")
            else
                rename!( joined, n => m[1]*"_v4") 
            end  
        end
    end 
    # add deltas of important stuff
    toskip_logs = Set{Int}()
    for c in CORR_TARGETS
        presym = Symbol( c * "_v3" )
        postsym = Symbol( c * "_v4")
        dsym = Symbol( "Δ_" * c )
        dlsym = Symbol( "Δ_log_" * c )
        joined[!,dsym] = joined[!,postsym] - joined[!,presym]
        joined[!,dlsym] = log.(joined[!,postsym]) - log.(joined[!,presym])
    end
    # I dare say there's a 1-liner version of this ... 
    i = 0
    for r in eachrow( joined )
        i += 1
        for c in CORR_TARGETS
            dlsym = Symbol( "Δ_log_" * c )
            v = r[dlsym]
            if isinf( v ) || isnan( v ) || ismissing( v )
                push!( toskip_logs, i )
            end 
        end 
    end
    sort!( stacked, [:PROLIFIC_PID,:EndDate])
    @assert size(joined)[1]*2 == size(stacked)[1] "n joined= $(size(joined)[1]*2); n stacked= $(size(stacked)[1])"
    joined, stacked, toskip_logs
end


  

function pre_post_scatter( 
    joined :: DataFrame,
    var :: String, 
    by  :: String,
    colours :: Dict )
    f = Figure()
    vname = pretty( var )
    vby = pretty( by )
    presym = Symbol( var* "_v3" )
    postsym = Symbol( var* "_v4")
    nobs = size( joined )[1]
    #= TODO FINISH circle sizes by count 
    predat = joined[!, presim]
    postdat = joined[!, postsim]
    sizes = fill( 1, nobs )
    if eltype( predat ) <: Integer 
        occurs = fill(0, nobs, nobs )
        # make_mat( joined[!, presim], joined[!, postsym ])
        for i in 1:nobs
            for j in 1:nobs
                occurs[ preddat[j], postdat[j]] += 1
            end
        end
    end
    =#
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

function analyse( joined :: DataFrame, dall3 :: DataFrame, dall4 :: DataFrame )
    anal = Dict()
    for c in CORR_TARGETS
        presym = Symbol( "$(c)_v3")
        postsym = Symbol( "$(c)_v4")
        fig_gender = pre_post_scatter( 
            joined, 
            c, 
            "Gender_v3",
            GENDER_MAP )
        fig_pol = pre_post_scatter( 
            joined, 
            c, 
            "next_election_v3",
            POL_MAP )
        s_v3 = summarystats( joined[!,presym] )
        s_v4 = summarystats( joined[!,postsym] )
        corr = cor( joined[ !, presym], joined[ !, postsym] )
        anal[c] = (; fig_gender, fig_pol, s_v3, s_v4, corr )         
    end
    
    # summaries from joined data
    counts_joined = (; gender=countmap(joined.Gender_v3), 
        vote_intention_2022=countmap(joined.next_election_v3), 
        vote_intention_2024=countmap(joined.next_election_v4),
        bi_lovers_v3=countmap(joined.lovers_post_v3), 
        bi_haters_v3=countmap(joined.haters_post_v3),
        bi_lovers_v4=countmap(joined.lovers_post_v4), 
        bi_haters_v4=countmap(joined.haters_post_v4),
        bi_0_v3=countmap(joined.zeros_post_v3),
        bi_100_v3=countmap(joined.hundreds_post_v3),
        bi_0_v4=countmap(joined.zeros_post_v4),
        bi_100_v4=countmap(joined.hundreds_post_v4))
    # and from indidivual datasets, to kinda sorta check 
    # for attrition bias
    counts_all = (; gender=countmap(dall3.Gender), 
        vote_intention_2022=countmap(dall3.next_election), 
        vote_intention_2024=countmap(dall4.next_election),
        bi_lovers_v3=countmap(dall3.lovers_post), 
        bi_haters_v3=countmap(dall3.haters_post),
        bi_lovers_v4=countmap(dall4.lovers_post), 
        bi_haters_v4=countmap(dall4.haters_post),
        bi_0_v3=countmap(dall3.zeros_post),
        bi_100_v3=countmap(dall3.hundreds_post),
        bi_0_v4=countmap(dall4.zeros_post),
        bi_100_v4=countmap(dall4.hundreds_post))

    return anal, counts_joined, counts_all
end

function do_delta_regs( joined :: DataFrame, toskip_logs :: Set ) :: Vector
    regs = []
    f1 = @formula( Δ_basic_income_post ~ 1 + Δ_HH_Net_Income_PA +  Δ_At_Risk_of_Destitution + Δ_gad_7 + Δ_phq_8 + Δ_Ladder + Age_v3 + Gender_v3 + next_election_v3 )
    push!( regs, lm( f1, joined ) )
    f2 = @formula( Δ_basic_income_post ~ 1 + Δ_HH_Net_Income_PA +  Δ_At_Risk_of_Destitution + Δ_gad_7 + Δ_phq_8 + Δ_Ladder + Age_v3 + Gender_v3 )
    push!( regs, lm( f2, joined ) )
    f3 = @formula( Δ_basic_income_post ~ 1 +  Δ_At_Risk_of_Destitution + Δ_gad_7 + Δ_phq_8 + Δ_Ladder + Age_v3 + Gender_v3 )
    push!( regs, lm( f3, joined ) )
    f4 = @formula( Δ_basic_income_post ~ 1 +  Δ_At_Risk_of_Destitution + Δ_Ladder + Age_v3 + Gender_v3 )
    push!( regs, lm( f4, joined ) )
    f5 = @formula( Δ_basic_income_post ~ 1 +  Δ_At_Risk_of_Destitution + Age_v3 + Gender_v3 )
    push!( regs, lm( f5, joined ) )
    f6 = @formula( Δ_basic_income_post ~ 1 +  Δ_At_Risk_of_Destitution )
    push!( regs, lm( f6, joined ) )
    n = size(joined)[1]
    todo = sort( setdiff(1:n, toskip_logs ))
    goodj = joined[todo,:]
    f1 = @formula( Δ_log_basic_income_post ~ 1 + Δ_log_HH_Net_Income_PA +  Δ_log_At_Risk_of_Destitution + Δ_log_gad_7 + Δ_log_phq_8 + Δ_log_Ladder + Age_v3 + Gender_v3 + next_election_v3 )
    push!( regs, lm( f1, goodj ) )
    f2 = @formula( Δ_log_basic_income_post ~ 1 + Δ_log_HH_Net_Income_PA +  Δ_log_At_Risk_of_Destitution + Δ_log_gad_7 + Δ_log_phq_8 + Δ_log_Ladder + Age_v3 + Gender_v3 )
    push!( regs, lm( f2, goodj ) )
    f3 = @formula( Δ_log_basic_income_post ~ 1 +  Δ_log_At_Risk_of_Destitution + Δ_log_gad_7 + Δ_log_phq_8 + Δ_log_Ladder + Age_v3 + Gender_v3 )
    push!( regs, lm( f3, goodj ) )
    f4 = @formula( Δ_log_basic_income_post ~ 1 +  Δ_log_At_Risk_of_Destitution + Δ_log_Ladder + Age_v3 + Gender_v3 )
    push!( regs, lm( f4, goodj ) )
    f5 = @formula( Δ_log_basic_income_post ~ 1 +  Δ_log_At_Risk_of_Destitution + Age_v3 + Gender_v3 )
    push!( regs, lm( f5, goodj ) )
    f6 = @formula( Δ_log_basic_income_post ~ 1 +  Δ_log_At_Risk_of_Destitution )
    push!( regs, lm( f6, goodj ) )
    regtable(regs[1:5]...;file="tmp/deltaregs-ols.html",number_regressions=true, stat_below = false, render=HtmlTable(), below_statistic = TStat )
    regs
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

function make_md_page( stats::Dict, counts_joined :: NamedTuple, counts_all :: NamedTuple )
    io = open( "tmp/v3-v4-insert.md", "w")
    println(io, "| | Correlation W3->W4 | mean W3| Mean W4 | Median W3 | Median W4 | SD W3 | SD W4 | N | | |")
    println(io, "| ------------ "^11, "|")
    for c in CORR_TARGETS
        pc = pretty( c )
        e = stats[c]
        save( "tmp/img/fig-gender-$(c).svg", e.fig_gender )
        save( "tmp/img/fig-pol-$(c).svg", e.fig_pol)
        print( io, "| $pc ")
        print( io, "| $(f2(e.corr))")
        print( io, "| $(f2(e.s_v3.mean))")
        print( io, "| $(f2(e.s_v4.mean))")
        print( io, "| $(f2(e.s_v3.median))")
        print( io, "| $(f2(e.s_v4.median))")
        print( io, "| $(f2(e.s_v3.sd ))")
        print( io, "| $(f2(e.s_v4.sd ))")
        print( io, "| ![image of $c by gender](img/fig-gender-$(c).svg) ")
        print( io, "| ![image of $c by pol](img/fig-pol-$(c).svg) ")
        println( io, "| $(e.s_v4.nobs ) |")
        # fig_gender, fig_pol, s_w3, s_w4, corr
    end
    println( io, "\n\n## SOME COUNTS\n")
    for c in [:gender, :vote_intention_2022, :vote_intention_2024, :bi_lovers_v3, :bi_lovers_v4, :bi_haters_v3, :bi_haters_v4, 
        :bi_0_v3, :bi_0_v4, :bi_100_v3, :bi_100_v4]
        mj = counts_joined[c]
        ma = counts_all[c]
        pmj = Dict()
        summj = sum( values(mj))
        pma = Dict()
        summa = sum( values(ma))
        for (k,v) in mj
            pmj[k] = f2(100*v/summj)
        end
        for (k,v) in ma
            pma[k] = f2(100*v/summa)
        end
        title = pretty( string(c))
        println( io, "### $title\n\n")
        println( io, "| | Count (In Both Samples) | % |Count (Inc. Dropouts) | % |")
        println( io, "| ------ | ------- | ------- | ------- | ------- |")
        for k in sort( collect(keys(mj) ))
            println( io,  "| $k | $(mj[k])| $(pmj[k]) | $(ma[k]) |$(pma[k]) |")
        end
        println( io, "\n\n")
    end
    println( io, "\n\n" )
    close( io )
end

function do_fixed_effects( stacked :: DataFrame ) :: Vector
    regs = []
    f = @formula(basic_income_post ~ At_Risk_of_Destitution + HH_Net_Income_PA + gad_7 + phq_8 + Ladder + trust_in_politics  + fe( PROLIFIC_PID ))
    push!( regs, reg( stacked, f ))
    f = @formula(basic_income_post ~ At_Risk_of_Destitution + HH_Net_Income_PA + gad_7 + phq_8 + Ladder + fe( PROLIFIC_PID ))
    push!( regs, reg( stacked, f ))
    f = @formula(basic_income_post ~ At_Risk_of_Destitution + HH_Net_Income_PA + gad_7 + phq_8 + fe( PROLIFIC_PID ))
    push!( regs, reg( stacked, f ))
    f = @formula(basic_income_post ~ At_Risk_of_Destitution + HH_Net_Income_PA + gad_7 + fe( PROLIFIC_PID ))
    push!( regs, reg( stacked, f ))
    f = @formula(basic_income_post ~ At_Risk_of_Destitution + HH_Net_Income_PA  + fe( PROLIFIC_PID ))
    push!( regs, reg( stacked, f ))
    f = @formula(basic_income_post ~ At_Risk_of_Destitution  + fe( PROLIFIC_PID ))
    push!( regs, reg( stacked, f ))
    f = @formula(basic_income_post ~ HH_Net_Income_PA  + fe( PROLIFIC_PID ))
    push!( regs, reg( stacked, f ))
    f = @formula(basic_income_post ~ At_Risk_of_Destitution + HH_Net_Income_PA + gad_7 + phq_8  + trust_in_politics + fe( PROLIFIC_PID ))
    push!( regs, reg( stacked, f ))
    f = @formula(basic_income_post ~ At_Risk_of_Destitution + HH_Net_Income_PA + gad_7 + trust_in_politics + fe( PROLIFIC_PID ))
    push!( regs, reg( stacked, f ))
    f = @formula(basic_income_post ~ At_Risk_of_Destitution + HH_Net_Income_PA + trust_in_politics  + fe( PROLIFIC_PID ))
    push!( regs, reg( stacked, f ))
    f = @formula(basic_income_post ~ At_Risk_of_Destitution  + trust_in_politics + fe( PROLIFIC_PID ))
    push!( regs, reg( stacked, f ))
    f = @formula(basic_income_post ~ HH_Net_Income_PA  + trust_in_politics + fe( PROLIFIC_PID ))
    push!( regs, reg( stacked, f ))
    regs
end