
module IncomesBase
#
# can't work out the iterators here.
#
using DataStructures

import Base
export IncomesList

@enum Incomes begin
    i1 = 1
    i2 = 2
    i3 = 3
    i4 = 99
end

import Base.sum
import Base.getindex 
import Base.maximum

const IncomesList2 = SortedDict{Incomes,Number}
const IncomesSet2 = SortedDict{Incomes}

"""
return 0 from a[k] if `k` is not a key of `a` 
"""
@inline function Base.getindex(m::IncomesList2, k :: Incomes )
    get( m, k, zero(eltype(values(m))) )
end

@inline Base.sum(m::IncomesList2) = sum(values(m))

@inline function mult!(i::IncomesList2, m::Number)
    for k in keys(i)
        i[k] = i[k] * m
    end
end

@inline function add!(i::IncomesList2, m::Number)
    for k in keys(i)
        i[k] = i[k] + m
    end
end

@inline Base.maximum(i::IncomesList2) = maximum(values(i))
@inline Base.minimum(i::IncomesList2) = minimum(values(i))

#= 

k = mergewith(+,i,j)
incs = IncomesList2[]
for i in 1:10
    inc = IncomesList2();for j in rand(1:3)
    inc[rand(instances(Incomes))] += rand(1:100)
    push!(incs,inc)
    end
end

k = IncomesList2()
for i in incs
    k = mergewith(+,k,i)
end

k = mergewith(+, i..., k )
=#

struct IncomesList{K,T<:Number}
    i :: SortedDict{K,T}
    
    function IncomesList{K,T}() where K where T 
        new{K,T}( SortedDict{K,T}())
    end

    function IncomesList{K,T}( stuff ) where K where T 
        new{K,T}( SortedDict{K,T}( stuff ))
    end
end

struct IncomesSet{K}
    s :: SortedSet{K}

    function IncomesSet{K}()
        new{K}( SortedSet{K}())
    end

    function IncomesSet{K}(stuff)
        new{K}( SortedSet{K}(stuff))
    end

end


function Base.keys( i::IncomesList )
    return keys(i.i)
end

function Base.values( i::IncomesList )
    return values(i.i)
end

function Base.show(io::IO, ::MIME"text/plain", i::IncomesList)
    for (k,v) in i.i
        println( "$k => $v")
    end
end

function Base.show(io::IO, ::MIME"text/plain", i::IncomesSet)
        print( join( i.s, ", " ))
end

function Base.show(io::IO, ::MIME"text/markdown", i::IncomesList)
    for (k,v) in i.i
        println( "* $k : **$v**")
    end
end

# FIXME this is odd way round for SortedDic
function Base.setindex!(i::IncomesList,v::T, key::K) where K where T<:Number
    i.i[key] = v
end

# FIXME this is odd way round for SortedDic
function Base.push!(i::IncomesSet, v::K) where K
    push!(i.i[key])
end

function Base.iterate(i::IncomesSet)
    iterate(i.s)
end

function Base.iterate(i::IncomesSet, state )
    iterate(i.s, state )
end


# not needed if iterate works
function Base.sum(i::IncomesList)
    return sum( values(i.i))
end

function sum(i::IncomesList{K,T}, s :: IncomesSet ) where K where T<: Number
    t = zero(T)
    for (k,v) in i
        if k in s
            t += v
        end
    end
    t
end

function Base.getindex(i::IncomesList,key::K) where K
    return get(i.i,key,0.0)
end

function Base.iterate(i::IncomesList)
    return iterate( i.i )
end #	Returns either a tuple of the first item and initial state or nothing if empty

function Base.iterate(i::IncomesList, state ) 
    return iterate( i.i, state )
end

function Base.length(i::IncomesList)
    return length(i.i)
end

Base.delete!( i::IncomesList, x ) = delete!( i.i, x )


Base.isempty(i::IncomesSet) = isempty(i.s)
Base.length(i::IncomesSet)  = length(i.s)
Base.in(x, i::IncomesSet) = in( x, i.s )
Base.pop!( x, i ) = pop!( x.s, i )
Base.delete!( i::IncomesSet, x ) = delete!( i.s, x )

struct IncludedItems{K}
    included :: IncomesSet{K}
    deducted :: IncomesSet{K}

    function IncludedItems{K}()
        new{K}( IncomesSet{K}(), IncomesSet{K}())
    end

    function IncludedItems{K}( included, deducted )
        new{K}( IncomesSet{K}(included), IncomesSet{K}(deducted))
    end

end

function sum( 
    incs :: IncomesList{K,T},  
    items :: IncludedItems{K} )::T where K where T <: Number
    return sum(incs, items.included) = sum( incs, items.deducted )
end

end # module