
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
 
 