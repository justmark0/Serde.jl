module SerRowBinary

export to_rowbinary

using Dates
using UUIDs
using NanoDates
using Sockets
using Printf
using ..Serde
using ..ParRowbinary

"""
    serialize_unsigned_leb128(value::UInt64) -> Vector{UInt8}

Serialize an unsigned 64-bit integer to LEB128 format.
"""
function serialize_unsigned_leb128(value::UInt64)::Vector{UInt8}
    result = UInt8[]
    while true
        byte = UInt8(value & 0x7f)
        value >>= 7
        if value != 0
            byte |= 0x80
        end
        push!(result, byte)
        value == 0 && break
    end
    return result
end

"""
    serialize_type(value::T, _type::Type = T) where T -> Vector{UInt8}

Serialize a value of type T to RowBinary format. 
_type is needed for strict type encoding T is not always the same as typeof(value).
Example: value = 3::Int32 but _type = Union{Nothing, Int32}.
"""
function serialize_type(value::T, _type::Type = T) where T
    if _type <: Integer
        return reinterpret(UInt8, [value])
    elseif _type <: AbstractFloat
        return reinterpret(UInt8, [value])
    elseif _type == Bool
        return UInt8[value ? 0x01 : 0x00]
    elseif _type == String
        size_bytes = serialize_unsigned_leb128(UInt64(length(value)))
        return vcat(size_bytes, Vector{UInt8}(value))
    elseif _type == Date
        days = Dates.value(value - Date(1970, 1, 1))
        return reinterpret(UInt8, [UInt16(days)])
    elseif _type == DateTime
        timestamp = Int32(Dates.value(value - DateTime(1970, 1, 1)) ÷ 1000)
        return reinterpret(UInt8, [timestamp])
    elseif _type == NanoDate
        nanoseconds = Int64(Dates.value(value - NanoDate(1970, 1, 1)))
        return reinterpret(UInt8, [nanoseconds])
    elseif _type <: ParRowbinary.DateTime64
        precision = _type.parameters[1]
        milliseconds = Int64(Dates.value(value.value - DateTime(1970, 1, 1)))
        if precision < 3
            milliseconds = milliseconds ÷ 10^(3 - precision)
        elseif precision > 3
            milliseconds *= 10^(precision - 3)
        end
        return reinterpret(UInt8, [milliseconds])
    elseif _type <: ParRowbinary.NanoDate64
        precision = _type.parameters[1]
        nanoseconds = Int64(Dates.value(value.value - NanoDate(1970, 1, 1)))
        if precision < 9
            nanoseconds = nanoseconds ÷ 10^(9 - precision)
        elseif precision > 9
            nanoseconds = nanoseconds * 10^(precision - 9)
        end
        return reinterpret(UInt8, [nanoseconds]) 
    elseif _type == Time
        seconds = Int32(value.instant.value ÷ 1_000_000_000)
        return reinterpret(UInt8, [seconds])
    elseif _type <: ParRowbinary.Decimal32
        return reinterpret(UInt8, [value.value])
    elseif _type <: ParRowbinary.Decimal64
        return reinterpret(UInt8, [value.value])
    elseif _type <: ParRowbinary.Decimal128
        return reinterpret(UInt8, [value.value])
    elseif _type == UUID
        uuid_string = string(value)
        uuid_parts = split(uuid_string, "-")
        
        return vcat(
            reverse([parse(UInt8, uuid_parts[3][i:i+1], base=16) for i in 1:2:4]),
            reverse([parse(UInt8, uuid_parts[2][i:i+1], base=16) for i in 1:2:4]),
            reverse([parse(UInt8, uuid_parts[1][i:i+1], base=16) for i in 1:2:8]),
            reverse([parse(UInt8, uuid_parts[5][i:i+1], base=16) for i in 1:2:12]),
            reverse([parse(UInt8, uuid_parts[4][i:i+1], base=16) for i in 1:2:4])
        )
    elseif _type == IPv4
        return reverse(reinterpret(UInt8, [ntoh(value.host)]))
    elseif _type == IPv6
        return reinterpret(UInt8, [ntoh(value.host)])
    elseif _type <: Vector
        size_bytes = serialize_unsigned_leb128(UInt64(length(value)))
        content = reduce(vcat, [serialize_type(item, eltype(_type)) for item in value])
        return vcat(size_bytes, content)
    elseif _type <: Tuple
        return reduce(vcat, [serialize_type(item, _type.types[i]) for (i, item) in enumerate(value)])
    elseif _type <: Dict
        size_bytes = serialize_unsigned_leb128(UInt64(length(value)))
        sorted_keys = sort(collect(keys(value)))
        content = reduce(vcat, [vcat(serialize_type(k, keytype(_type)), serialize_type(value[k], valtype(_type))) for k in sorted_keys])
        return vcat(size_bytes, content)
    elseif typeof(_type) == Union && ParRowbinary.union_has_nothing(_type)
        if isnothing(value)
            return UInt8[0x01]  # NULL
        else
            inner_type = _type.b != Nothing ? _type.b : _type.a
            return vcat(UInt8[0x00], serialize_type(value, inner_type))
        end
    else
        error("Unsupported type: $_type")
    end
end

(ser_name(::Type{T}, k::Val{x})::Symbol) where {T,x} = Serde.ser_name(T, k)
(ser_value(::Type{T}, k::Val{x}, v::V)) where {T,x,V} = Serde.ser_value(T, k, v)
(ser_type(::Type{T}, v::V)) where {T,V} = Serde.ser_type(T, v)

(ser_ignore_field(::Type{T}, k::Val{x})::Bool) where {T,x} = Serde.ser_ignore_field(T, k)
(ser_ignore_field(::Type{T}, k::Val{x}, v::V)::Bool) where {T,x,V} = ser_ignore_field(T, k)
(ser_ignore_null(::Type{T})::Bool) where {T} = false

"""
    to_rowbinary(data::T) -> Vector{UInt8}

Serialize any data of type T to RowBinary format.

## Examples

```julia-repl
julia> struct Person
           name::String
           age::Int64
       end

julia> person = Person("Alice", 30)
Person("Alice", 30)

julia> binary_data = to_rowbinary(person)
UInt8[0x05, 0x41, 0x6c, 0x69, 0x63, 0x65, 0x1e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
```
"""
function to_rowbinary(data::T)::Vector{UInt8} where T
    result = UInt8[]
    for field in fieldnames(T)
        value = getfield(data, field)
        if !ser_ignore_field(T, Val(field), value)
            field_type = fieldtype(T, field)
            append!(result, serialize_type(value, field_type))
        end
    end
    return result
end

end
