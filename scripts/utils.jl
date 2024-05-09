
using CSV,DataFrames,Tidier

function loaddf( dir::String, year::Int, table::String )::DataFrame
    df = CSV.File( "$(dir)/$(table).tab") |> DataFrame
    df.year = fill( year, size(df)[1])
    rename!( df, lowercase.(names(df)))
    df
end

function loadfrs( year::Int, table="househol" )::DataFrame
    dir = "/mnt/data/frs/$(year)/tab"
    return loaddf( dir, year, table )
 end


function rename( ins :: String, m :: Dict )::String
    get( m, ins, ins )
end

function renamecol!( d ::DataFrame, col :: Symbol, renames :: Dict )
    for r in eachrow(d)
        r[col] = rename( r[col], renames )
    end
end

function ustack( d :: DataFrame )
    unstack(d[!,[1,2]],1,2)[1,:]
    rename!( d, renames )
end

 
 