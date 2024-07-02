
using StatsBase, CSV, DataFrames

wass = CSV.File( "../ScottishTaxBenefitModel/data/was_wave_7_subset.tab")|>DataFrame
ind=CSV.File( "../ScottishTaxBenefitModel/data/was-wave-7-frs-scotland-only-matches-2015-2021.tab")|>DataFrame
#
# version with lower Scot region weight
#
ind2=CSV.File( "../ScottishTaxBenefitModel/data/was-wave-7-frs-scotland-only-matches-2015-2021-w2.tab")|>DataFrame

# with was/frs own income 
ind3=CSV.File( "../ScottishTaxBenefitModel/data/was-wave-7-frs-scotland-only-matches-2015-2021-w3.tab")|>DataFrame

was_sel = wass[(wass.case .∈ ((ind.was_case_1),)),:]
was_sel2 = wass[(wass.case .∈ ((ind2.was_case_1),)),:]
was_sel3 = wass[(wass.case .∈ ((ind3.was_case_1),)),:]

countmap( ind.was_case_1 )

# more WAS cases used
countmap( ind2.was_case_1 )
# more WAS cases used
countmap( ind3.was_case_1 )

size(ind)

sort(countmap( wass.region ))

sort(countmap( was_sel.region ))

sort(countmap( was_sel2.region ))

# Scotland! overrepresented 

#=

OrderedCollections.OrderedDict{Int64, Int64} with 11 entries:
  112000001 => 879
  112000002 => 2065
  112000003 => 1776
  112000004 => 1510
  112000005 => 1559
  112000006 => 1803
  112000007 => 1319
  112000008 => 2368
  112000009 => 1806
  299999999 => 1514
  399999999 => 933

julia> sort(countmap( was_sel.region ))
OrderedCollections.OrderedDict{Int64, Int64} with 11 entries:
  112000001 => 283
  112000002 => 643
  112000003 => 545
  112000004 => 164
  112000005 => 137
  112000006 => 39
  112000007 => 29
  112000008 => 87
  112000009 => 25
  299999999 => 1275
  399999999 => 81

julia> sort(countmap( was_sel2.region ))
       
       # Scotland! overrepresented 
OrderedCollections.OrderedDict{Int64, Int64} with 11 entries:
  112000001 => 351
  112000002 => 817
  112000003 => 691
  112000004 => 218
  112000005 => 203
  112000006 => 150
  112000007 => 113
  112000008 => 206
  112000009 => 133
  299999999 => 1228
  399999999 => 123

=#

sort(countmap( ind2.was_case_1 ), rev=true, byvalue=true )
#= was records with over 100 mappings, v2:

OrderedDict{Int64, Int64} with 4233 entries:
  7566  => 212
  8704  => 202
  7147  => 190
  10052 => 180
  16941 => 163
  14385 => 161
  11436 => 159
  15504 => 149
  12085 => 135
  9533  => 130
  1639  => 108
=#

sort(countmap( ind3.was_case_1 ), rev=true, byvalue=true )
#= v3 - much better
 12848 => 103
  8704  => 68
  16339 => 61
  14385 => 53
  978   => 53
  5210  => 50
  6076  => 47
  15312 => 45
  13646 => 44
  2442  => 43
  933   => 43

=#

was_highmap_2 = wass[wass.case .∈ ([7566,8704,7147,10052,16941,14385,11436,15504,12085,9533,1639],),:]
was_highmap_3 = wass[wass.case .∈ ([12848, 8704, 16339, 14385, 978, 5210, 6076, 15312, 13646],),:]

#=
all low income hhlds in Scotland, with 0 wages and 0 SE
=#

# == TRY WITH WAS/FRS computed hh income 

capcomp = CSV.File( "data/capcompare.tab")|>DataFrame
capcomp_w3 = CSV.File( "data/capcompare-w3.tab")|>DataFrame


