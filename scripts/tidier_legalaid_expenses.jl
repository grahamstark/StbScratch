using Tidier,DataFrames,CSV,PrettyTables,Format,CategoricalArrays
using ScottishTaxBenefitModel
using .Utils

function count_pct(v, r, c)
   if c == 1
      return pretty(v)
   elseif c == 2
      return Format.format(v,precision=0, commas=true)
   elseif c == 3
      return Format.format(v,precision=2)
   else
      return v
   end
end

function money_amt(v, r, c)
   if c == 1
      return pretty(v)
   else
      return Format.format(v,precision=2, commas=true)
   end
end


df = CSV.File( "/tmp/output/test_of_inferred_capital_2_off_1_legal_aid_civil.tab")|>DataFrame
outf = open( "tmp/summary_stuff_for_kieran.md","w")

expenses = @chain df begin
         @group_by( entitlement )
         @summarize( 
            mean_childcare = sum( childcare .* weight )/sum(weight),
            mean_housing = sum( housing .* weight )/sum(weight),
            mean_work_expenses = sum( work_expenses .* weight )/sum(weight),
            mean_repayments = sum( repayments .* weight )/sum(weight),
            mean_maintenance = sum( maintenance .* weight )/sum(weight),
            mean_outgoings = sum( outgoings .* weight )/sum(weight))
end

println( outf, "## Expenses")
pretty_table( outf, expenses, formatters=money_amt , backend = Val(:markdown), cell_first_line_only=true)

println( outf, "## UC")

uccount = @chain df begin
          @filter( (uc_entitlement > 0) & (! is_child ) & (is_bu_head))
          # @mutate( tot = sum( weight ))
          @group_by( employment_status )
          @summarize( n=sum(weight) )
          # @mutate( pct = 100*n/tot)
end

tot = sum( uccount.n)
uccount.pct = 100.0 .* uccount.n ./ tot

pretty_table( outf, uccount, formatters=count_pct , backend = Val(:markdown), cell_first_line_only=true)

frshh17 = CSV.File( "/mnt/data/frs/2017/tab/househol.tab") |> DataFrame
frshh18 = CSV.File( "/mnt/data/frs/2018/tab/househol.tab") |> DataFrame
frshh19 = CSV.File( "/mnt/data/frs/2019/tab/househol.tab") |> DataFrame
frshh20 = CSV.File( "/mnt/data/frs/2020/tab/househol.tab") |> DataFrame
frshh21 = CSV.File( "/mnt/data/frs/2021/tab/househol.tab") |> DataFrame
rename!( frshh17, lowercase.(names(frshh17)))
frshh17.year = fill( 2017, size(frshh17)[1])
rename!( frshh18, lowercase.(names(frshh18)))
frshh18.year = fill( 2018, size(frshh18)[1])
rename!( frshh19, lowercase.(names(frshh19)))
frshh19.year = fill( 2019, size(frshh19)[1])
rename!( frshh20, lowercase.(names(frshh20)))
frshh20.year = fill( 2020, size(frshh20)[1])
rename!( frshh21, lowercase.(names(frshh21)))
frshh21.year = fill( 2021, size(frshh21)[1])

frshh = vcat( frshh17, frshh18, frshh19, frshh20, frshh21; cols=:intersect )

frshh.xweight = Weights(frshh.gross4)./3

avcosts = @chain frshh begin
   @group_by( tentyp2, year )
   @mutate( hhrent = max(0, hhrent ), 
            mortpay=max(0, mortpay), 
            mortint=max(0,mortint ))
   @summarise( 
      m_rent = sum( hhrent.*xweight)/sum(xweight),
      m_mort = sum( mortint.*xweight )/sum(xweight), # Weights(gross4)), 
      m_mortpay= sum(mortpay.*xweight)/sum(xweight)) #, Weights(gross4)))
   @arrange( tentyp2 )
end

for c in collect(avcosts)
   pretty_table(c)
end

close(outf)
