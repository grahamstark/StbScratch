using Tidier,DataFrames,CSV,PrettyTables,Format
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

close(outf)
