
using CSV,DataFrames,StatsBase,ArgCheck
using ScottishTaxBenefitModel
using .LegalAidOutput,.LegalAidData 
using .GeneralTaxComponents: WEEKS_PER_YEAR

"""
FIXME not used as it's really slow
"""
function get_sample_case_cost( 
    hsm:: AbstractString, 
    # status::String, 
    sex::AbstractString, 
    age2::AbstractString,
    contrib::Number,
    is_aa :: Bool )::Number
    costs = is_aa ? LegalAidData.CIVIL_COSTS : LegalAidData.AA_COSTS 
    paid = costs[(costs.age2.==age2) .& (costs.sex.==sex) .& (costs.hsm_censored .== hsm ),:totalpaid]
    npaid = size(paid)[1]
    tot = 0.0
    for i in 1:npaid
        tot += min( contrib, paid[i])
    end
    println( "hsm $hsm npaid $npaid tot")
    return npaid == 0 ? 0.0 : tot/npaid
end

"""
pre: results with merged propensities
post: results with merged propensities
FIXME: clean this up drastically
"""
function make_summary_tab(
    pre :: DataFrame,
    post :: DataFrame,
    is_aa :: Bool;
    weight_sym = :weight )
    @argcheck size(pre)==size(post)
    nrows,ncols = size(pre)    
    weeks = is_aa ? 1.0 : WEEKS_PER_YEAR
    tab = DataFrame( 
        labels=["Cases","Gross Cost","Contributions","Net Cost"],
        pre=zeros(4),
        post=zeros(4),
        change=zeros(4))
    is_aa = true
    prop_cols = [
        "adults_with_incapacity",
        "contact_or_parentage",
        "family_or_matrimonial_other",
        "other",
        "residence"]
    tsize = size(prop_cols)[1]
    for row in 1:nrows
        pr = pre[row,:]
        po = post[row,:]
        w = pr[weight_sym]
        @assert w == po[weight_sym]
        max_contrib_pr = 
            pr.income_contribution_amt*weeks
            pr.capital_contribution_amt
        max_contrib_po = 
            po.income_contribution_amt*weeks
            po.capital_contribution_amt
        for i in 1:tsize 
            tc = Symbol(prop_cols[i]*"_prop")
            tcost = Symbol(prop_cols[i]*"_cost")
            tab[1,2] += w*pr[tc]
            tab[1,3] += w*po[tc]
            tab[2,2] += w*pr[tc]*pr[tcost]
            tab[2,3] += w*po[tc]*pr[tcost]
            # scase_pr = get_sample_case_cost( prop_cols[i], pr.sex, pr.age2, max_contrib_pr, is_aa )/1000.0
            # scase_po = get_sample_case_cost( prop_cols[i], pr.sex, pr.age2, max_contrib_po, is_aa )/1000.0
            tab[3,2] += w*pr[tc]*max_contrib_pr/1000 #*scase_pr # 
            tab[3,3] += w*po[tc]*max_contrib_po/1000 # scase_po # 
        end
    end
    tab[4,2] = tab[2,2] - tab[3,2]
    tab[4,3] = tab[2,3] - tab[3,3]
    tab[:,4] = tab[:,3] .- tab[:,2]
    return tab
end

data_aa=CSV.File( "/tmp/output/local_legal_aid_runner_test_v2_1_legal_aid_aa.tab")|>DataFrame
props_aa = CSV.File("/tmp/output/legal_aid_aa_propensities.tab")|>DataFrame
pre_aa = data_aa
post_aa= data_aa
#=
pre = LegalAidOutput.merge_in_probs_and_props( 
    data1, 
    LegalAidData.LA_PROB_DATA, 
    props1 )
post = LegalAidOutput.merge_in_probs_and_props( 
    data1, 
    LegalAidData.LA_PROB_DATA, 
    props1 )
=#
st_aa =  make_summary_tab( pre_aa, post_aa, true )

data_civ=CSV.File( "/tmp/output/local_legal_aid_runner_test_v2_1_legal_aid_civil.tab")|>DataFrame
props_civ = CSV.File("/tmp/output/legal_aid_civil_propensities.tab")|>DataFrame
pre_civ = data_civ
post_civ = data_civ

#=
pre2 = LegalAidOutput.merge_in_probs_and_props( 
    data2, 
    LegalAidData.LA_PROB_DATA, 
    props2 )
post2 = LegalAidOutput.merge_in_probs_and_props( 
    data2, 
    LegalAidData.LA_PROB_DATA, 
    props2 )
=#
st_civ =  make_summary_tab( pre_civ, post_civ, false )

costs = LegalAidData.CIVIL_COSTS
costs[(costs.la_status.==la_none).&(costs.hsm_censored .!= "adults_with_incapacity"),:]

gc_civ = groupby(costs,[:hsm])

size(gc_civ[2])==2579


data_civ[data_civ.entitlement.=="la_none",[:entitlement,:contact_or_parentage_prop]]
sum(data_civ.contact_or_parentage_prop.*data_civ.weight) # 4794.40487416573

labs=["Full_time_Employee"
 "Full_time_Self_Employed"
 "Looking_after_family_or_home"
 "Missing_ILO_Employment"
 "Other_Inactive"
 "Part_time_Employee"
 "Part_time_Self_Employed"
 "Permanently_sick_or_disabled"
 "Retired"
 "Student"
 "Temporarily_sick_or_injured"
 "Unemployed"]
 x=LegalAidOutput.combine_one_legal_aid( data_civ, LegalAidOutput.LA_TARGETS[1], [:wt_contact_or_parentage],["Contact"])
 