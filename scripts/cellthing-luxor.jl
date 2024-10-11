
using Format
using Luxor
using ArgCheck

const GAIN_COLOUR = "#d1e7dd"
const LOSE_COLOUR = "#f8d7da"
const NC_COLOUR = "#cfe2ff"
const TOTALS_COLOUR = "#cff4fc"
const BORDER_COLOUR = "#dee2e6"
const HEADER_COLOR = "#b63b5e"
const FONT = "Azo Sans"
const FONT_SIZE = 15
const CELL_LABELS = ["Completely Disagree", "Mostly Disagree", "Mostly Neutral", "Mostly Agree", "Completely Agree", "TOTALS"]

function fp(x::AbstractFloat)
    if x ≈ 0
        return ""
    end 
    Format.format(x,precision=1,commas=false)
end

function fp(x::Number) 
    if x ≈ 0
        return ""
    end 
    Format.format(x,commas=true)
end 

fp(x) = x

function draw_crosstab( a::Matrix; cellsize=(200,150), labels::Vector{String})
    nr,nc = collect(size(a)) .+ 1

    table = Table((nr,nc), cellsize)
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
                ns = fp(a[ar,ac])
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
                
                # markup=true )
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

function draw_number_circles( 
    counts::Vector, colours :: Vector, total :: Number )
    sp, colours = sorted_positives( counts, colours )
    radai = Int.(ceil.(100 .* sp ./ total ))
    n = size(radai)
    
    radai
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

@svg begin
    pos = Point( 0,-520)
    setcolor(HEADER_COLOR)
    setfont(FONT,FONT_SIZE*3)
    settext( "CROSSTAB OF X by Y", pos, halign="center", valign="bottom", markup=true ) 
    # translate(150, 150)
    draw_crosstab(a; labels=CELL_LABELS)
    pos = Point( 0,-430)
    setcolor("Grey60")
    setfont(FONT,FONT_SIZE*2)
    settext( "After Treatment", pos; halign="center", valign="bottom", markup=true ) 
    pos = Point(-730, 200)
    settext( "Before Treatment", pos; angle=90 ) # halign="center", valign="bottom", markup=true ) 
    translate( 780, 0 )
    drawkey(; colours=["red","blue","yellow","orange","black"], labels=["red","blue","yellow","orange","black"])
end 2000 2000 "xx.svg"

function to_pct( a :: Matrix{Int})::Matrix
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
    return o
end