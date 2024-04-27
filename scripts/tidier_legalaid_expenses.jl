using StatsBase,Tidier,DataFrames,CSV,PrettyTables,Format,CategoricalArrays #,Cleaner
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

function loadfrs( year::Int, table="househol" )::DataFrame
   df = CSV.File( "/mnt/data/frs/$(year)/tab/$(table).tab") |> DataFrame
   df.year = fill( year, size(df)[1])
   rename!( df, lowercase.(names(df)))
end



tot = sum( uccount.n)
uccount.pct = 100.0 .* uccount.n ./ tot

pretty_table( outf, uccount, formatters=count_pct , backend = Val(:markdown), cell_first_line_only=true)

frshh17 = loadfrs(2017) # CSV.File( "/mnt/data/frs/2017/tab/househol.tab") |> DataFrame
frshh18 = loadfrs(2018)
frshh19 = loadfrs(2019)
frshh20 = loadfrs(2020)
frshh21 = loadfrs(2021)
frshh = vcat( frshh17, frshh18, frshh19, frshh20, frshh21; cols=:intersect )

frsmaint21 = loadfrs( 2021, "maint" )
frsmort21 = loadfrs( 2021, "mortgage" )
frsend21 = loadfrs( 2021, "endowmnt" )
frscont21 = loadfrs( 2021, "mortcont" )
frspers21 = loadfrs( 2021, "person" )
hbai = CSV.File("/mnt/data/hbai/UKDA-5828-tab/tab/i1821e_2122prices.tab")|>DataFrame 
rename!( hbai, lowercase.(names(hbai)))

frshh.xweight = Weights(frshh.gross4./5)

avcosts_frs = @chain frshh begin
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

for c in collect(avcosts_frs)
   pretty_table(c)
end

# i1821e_2122prices.tab

 @chain frshh begin
   @mutate( gbhscost = max.(0,gbhscost), hhrent=max.(0,hhrent), mortint=max(0,mortint))
   @group_by(gvtregn,year,tentyp2)
   @summarise( m_hc = mean( gbhscost ),m_int=mean(mortint), m_rent=mean(hhrent)) 
   @arrange(year,tentyp2,gvtregn)
 end


close(outf)
