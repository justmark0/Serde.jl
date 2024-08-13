module DeRowbinary

export deser_rowbinary

using ..ParRowbinary
import ..to_deser

"""
    deser_rowbinary(::Type{T}, x) -> T

Creates a new object of type `T` and fill it with values from RowBinary formated data `x` (Vector{UInt8} or AbstractString).

## Examples
```julia-repl
julia> struct Person
           name::String
           age::Int64
       end

julia> data = UInt8[0x05, 0x41, 0x6c, 0x69, 0x63, 0x65, 0x1e, 0x00, 0x00, 0x00, 
                    0x00, 0x00, 0x00, 0x00]

julia> result = deser_rowbinary(Person, data)
Person("Alice", 30)
```
"""
function deser_rowbinary(::Type{T}, x::Vector{UInt8})::T where T
    return parse_rowbinary(T, x)
end

function deser_rowbinary(::Type{T}, x::AbstractString)::T where T
    return deser_rowbinary(T, Vector{UInt8}(x))
end

deser_rowbinary(::Type{Nothing}, _) = nothing
deser_rowbinary(::Type{Missing}, _) = missing

end
