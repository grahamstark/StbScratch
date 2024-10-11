
using Format
using Luxor
using ArgCheck
using Colors 
using StatsBase
using DataFrames

const GAIN_COLOUR = "#d1e7dd"
const LOSE_COLOUR = "#f8d7da"
const NC_COLOUR = "#cfe2ff"
const TOTALS_COLOUR = "#cff4fc"
const BORDER_COLOUR = "#dee2e6"
const HEADER_COLOR = "#b63b5e"
const FONT = "Azo Sans"
const FONT_SIZE = 15
const CELL_LABELS = ["Completely Disagree", "Mostly Disagree", "Mostly Neutral", "Mostly Agree", "Completely Agree", "TOTALS"]
const ALL_COLOURS = distinguishable_colors(50)[3:end] # sort(collect(Colors.color_names))
const CELL_SIZE = (200,150)

function fp(x::AbstractFloat)
    if x ≈ 0
        return ""
    end 
    Format.format(x,precision=2,commas=false)
end

function fp(x::Number) 
    if x ≈ 0
        return ""
    end 
    Format.format(x,commas=true)
end 

fp(x) = x

function draw_number_circles( 
    counts::Vector, colours :: Vector, total :: Number )
    sp, colours = sorted_positives( counts, colours )
    radai = Int.(ceil.(30 .* sqrt.(sp ./ total )))
    n = length(radai)
    if n > 0
        widths = (2 .* radai ) .+ 10
        println( "widths $widths")
        t = Table( [50], widths ) #fill(40,n),  )
        # t = Table( (n, ), (100,100) )
        for i in 1:n
            setcolor( colours[i])
            circle(t[1,i], radai[i], action=:fill )
            # box(t, 1, i, action=:stroke)
        end
    end
end


function draw_crosstab( 
    ;
    percents::Matrix, 
    total :: Number,
    cell_contents::Matrix, 
    labels::Vector{String})
    nr, nc = collect(size(percents)) .+ 1
    table = Table( (nr,nc), CELL_SIZE )
    setfont(FONT, FONT_SIZE )
    for r in 1:nr
        for c in 1:nc          
            colour = 
                if c == 1 || r == 1
                    "white"
                elseif r == c
                    NC_COLOUR
                elseif r == nr || c == nc
                    TOTALS_COLOUR
                elseif r > c
                    LOSE_COLOUR
                elseif r < c 
                    GAIN_COLOUR
                end
            setcolor( colour)
            box(table, r, c, action=:fill)
            if c == 1 || r == 1 
                ;
            else
                setcolor( BORDER_COLOUR )
                box(table, r, c, action=:stroke)
            end
            setcolor("black");
            ar = r - 1
            ac = c - 1
            pos = table[r,c]
            s = if ar > 0 && ac > 0
                ns = fp(percents[ar,ac])
                pos += Point( 0, 40 )
                if r == nr || c == nc # row/col tots bold
                    ns = "<b>$ns</b>"
                end
                ns
            elseif ac == 0 && ar == 0
                ""
            elseif ar == 0
                pos += Point(0,60)
                "<b>$(labels[ac])</b>"
            elseif ac == 0
                # pos += Point(60,0)
                "<b>$(labels[ar])</b>"
            end 
            settext( s, pos; halign="center", valign="bottom", markup=true ) #table[r,c], 
            if(r in 2:nr) && (c in 2:nc)
                pos = table[r,c] - Point( 0, 20 )
                gsave()
                translate(pos)
                v = cell_contents[ar,ac][1]
                c = cell_contents[ar,ac][2]
                draw_number_circles(v,c,total)  
                grestore()              
            end
        end
    end # row
end

function sorted_positives( v :: Vector, colours :: Vector )
@argcheck length( v ) == length(colours)
    vt = eltype(v)
    n = length(v)
    d = Dict{vt,Vector}()
    for i in 1:n
        c = get( d, v[i], [])
        push!(c, colours[i])
        d[v[i]] = c
    end
    v1 = sort(v; rev=true)
    n = searchsortedfirst(v1,0, rev=true)-1
    ocolours = []
    for i in 1:n
        push!(ocolours, d[v[i]]...)
    end
    return v1[1:n], ocolours
end

function drawkey(; colours::Vector, labels :: Vector )
@argcheck length( colours ) == length(labels)
    # setfont(FONT,12)
    # setcolor( "black")
    # settext( "Key", Point(10,-60))
    n = length(labels)
    t = Table(fill(40,n), [25,80])
    println( size(t))
    for i in 1:n
        setcolor( colours[i])
        circle(t[i,1], 7; action=:fill)
        setcolor( "black")
        settext( labels[i], t[i,2]-Point(-10,0); valign="center")
    end
end

"""
test data WRONG TOO TIRED TO FIX
"""
function splitupcell( v :: Number, n :: Int )::Tuple
    remain = v
    vs = []
    colours = []
    r = 0
    for i in 1:n
        r = rand( 1:remain )
        push!(colours, ALL_COLOURS[i])
        if(remain - r ) <= 0
            push!( vs, remain )
            push!( vs, r)
            push!(colours, ALL_COLOURS[i])
            break
        else
            remain -= r
            push!(vs, r )
        end
        println( "r = $r remain=$remain")
    end
    # println( vs )
    # @assert( sum(vs) ≈ v )
    vs, colours
end

function testdraw( a :: Matrix )
    pct, tot = to_pct(a)
    cellcont = testsplits(a)
    @svg begin
        pos = Point( 0,-520)
        setcolor(HEADER_COLOR)
        setfont(FONT,FONT_SIZE*3)
        settext( "CROSSTAB OF X by Y", pos, halign="center", valign="bottom", markup=true ) 
        # translate(150, 150)
        draw_crosstab(
            percents=pct,
            total=tot,
            cell_contents=cellcont,
            labels=CELL_LABELS)
        pos = Point( 0,-430)
        setcolor("Grey60")
        setfont(FONT,FONT_SIZE*2)
        settext( "After Treatment", pos; halign="center", valign="bottom", markup=true ) 
        pos = Point(-720, 200)
        settext( "Before Treatment", pos; angle=90 ) # halign="center", valign="bottom", markup=true ) 
        translate( 780, 0 )
        drawkey(; colours=["red","blue","yellow","orange","black"], labels=["red","blue","yellow","orange","black"])
    end 2000 2000 "xx.svg"
end

function testsplits( a :: Matrix, n = 5 )::Matrix
    nrows, ncols = size(a)
    o = fill(([],[]), nrows+1, ncols+1 )
    for c in 1:ncols
        o[nrows+1,c] = splitupcell( sum( a[:,c]), n )
    end
    for r in 1:nrows
        o[r,ncols+1] = splitupcell( sum( a[r,:]), n )
    end
    o[nrows+1,ncols+1] = splitupcell( sum( a ), n )
    for r in 1:nrows
        for c in 1:ncols
            o[r,c] = splitupcell( a[r,c], n )
        end
    end
    return o
end

function to_pct( a :: Matrix )::Tuple
@argcheck size(a)[1] == size(a)[2] # square
    nrows,ncols = collect(size( a )) .+= 1
    o = zeros(nrows,ncols)
    o[1:nrows-1,1:ncols-1] = a
    for c in 1:ncols-1
        o[nrows,c] = sum( a[:,c])
    end
    for r in 1:nrows-1
        o[r,ncols] = sum( a[r,:])
    end
    t = sum(a)
    o[nrows,ncols] = t
    for i in CartesianIndices(o)
        o[i] = o[i]*100/t
    end
    return o, t
end

function bdrange( i :: Int )
    return if i == 0
        1
    elseif i < 30
        2
    elseif i < 70
        3
    elseif i < 100
        4
    else 
        5
    end
end

function sexsplitter( s :: AbstractString )::Int
    return if s == "Male" # => :dodgerblue4,
        1
    elseif s == "Female" # => :deeppink3,
        2
    else
        rand(1:2)
    end
    # "Other" => :grey
end

function create_crosstab(
    data    :: DataFrame,
    target  :: String,
    breakdown :: Symbol,
    bd_colours :: Vector,
    bd_splitter :: Function )::Tuple
    pol_pre = Symbol("$(target)_pre")
    pol_post = Symbol("$(target)_post")
    nrows = 5; ncols = 5
    totals = zeros(nrows,ncols)
    breakdowns = fill(([],[]), nrows+1, ncols+1 )
    nlevs = length( bd_colours )
    println(breakdowns)
    for r in 1:(nrows+1)
        for c in 1:(ncols+1)
            breakdowns[r,c] = ( zeros(nlevs), bd_colours )
        end
    end
    for row in eachrow(data)
        c = bdrange(row[pol_pre])
        r = bdrange(row[pol_post])
        totals[r,c] += row.weight
        target = bd_splitter( row[breakdown])
        breakdowns[r,c][1][target] += row.weight
        breakdowns[r,ncols+1][1][target] += row.weight
        breakdowns[nrows+1,c][1][target] += row.weight
    end
    pcts, total = to_pct( totals )
    totals, breakdowns, pcts, total
end

function draw_crosstab(
    filename :: String,
    title :: String,
    percents :: Matrix,
    cellconts :: Matrix,
    total :: Number,
    colours :: Vector,
    labels  :: Vector)
    pct, tot = to_pct(a)
    # cellcont = testsplits(a)
    @svg begin
        pos = Point( 0,-520)
        setcolor(HEADER_COLOR)
        setfont(FONT,FONT_SIZE*3)
        settext( "$(title) Approval, pre and post argument", pos, halign="center", valign="bottom", markup=true ) 
        # translate(150, 150)
        draw_crosstab(
            percents=percents,
            total=total,
            cell_contents=cellconts,
            labels=CELL_LABELS )
        pos = Point( 0,-430)
        setcolor("Grey60")
        setfont(FONT,FONT_SIZE*2)
        settext( "After Treatment", pos; halign="center", valign="bottom", markup=true ) 
        pos = Point(-720, 200)
        settext( "Before Treatment", pos; angle=90 ) # halign="center", valign="bottom", markup=true ) 
        translate( 780, 0 )
        drawkey(; colours=colours, labels=labels)
    end 2000 2000 filename*".svg"
end

#=
io = open( "tmp/links.md", "w")
for p in POLICIES
    filename = "img/$(p)-crosstab-by-gender"
    title = POLICY_LABELS[p]
    println( io, "![Image of $title]($(filename).svg)\n\n")
    totals, breakdowns, pcts, total = create_crosstab( 
        dall, 
        string(p), 
        :Gender, 
        ["dodgerblue4","deeppink3"], 
        sexsplitter )
    draw_crosstab( 
        "tmp/$(filename)", 
        title, 
        pcts, 
        breakdowns, 
        total, 
        ["dodgerblue4","deeppink3"], 
        ["Male", "Female"] )
end
close(io)
=#

