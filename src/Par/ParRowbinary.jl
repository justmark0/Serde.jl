module ParRowbinary

export RowBinarySyntaxError
export parse_rowbinary

using Dates
using UUIDs
using NanoDates
using Sockets
using Printf

"""
    RowBinarySyntaxError <: Exception

Exception thrown when a [`parse_rowbinary`](@ref) fails due to incorrect RowBinary syntax or any underlying error that occurs during parsing.

## Fields
- `message::String`: The error message.
- `exception::Exception`: The caught exception.
"""
struct RowBinarySyntaxError <: Exception
    message::String
    exception::Exception
end

Base.show(io::IO, e::RowBinarySyntaxError) = print(io, e.message)

"""
    AbstractDecimal{P}

Abstract type for fixed-precision decimal numbers.

## Type parameters
- `P`: Precision (number of decimal places)
"""
abstract type AbstractDecimal{P} end

"""
    Decimal32{P} <: AbstractDecimal{P}

32-bit fixed-precision decimal number.

## Fields
- `value::Int32`: The value multiplied by 10^P
- `precision::UInt8`: The precision (number of decimal places)

## Constructor
    Decimal32{P}(value::Integer) where P

Creates a new `Decimal32` instance with the given value and precision.
"""
struct Decimal32{P} <: AbstractDecimal{P}
    value::Int32
    precision::UInt8
    
    function Decimal32{P}(value::Integer) where P
        new{P}(Int32(value), UInt8(P))
    end
end

"""
    Decimal64{P} <: AbstractDecimal{P}

64-bit fixed-precision decimal number.

## Fields
- `value::Int64`: The value multiplied by 10^P
- `precision::UInt8`: The precision (number of decimal places)

## Constructor
    Decimal64{P}(value::Integer) where P

Creates a new `Decimal64` instance with the given value and precision.
"""
struct Decimal64{P} <: AbstractDecimal{P}
    value::Int64
    precision::UInt8
    
    function Decimal64{P}(value::Integer) where P
        new{P}(Int64(value), UInt8(P))
    end
end

"""
    Decimal128{P} <: AbstractDecimal{P}

128-bit fixed-precision decimal number.

## Fields
- `value::Int128`: The value multiplied by 10^P
- `precision::UInt8`: The precision (number of decimal places)

## Constructor
    Decimal128{P}(value::Integer) where P

Creates a new `Decimal128` instance with the given value and precision.
"""
struct Decimal128{P} <: AbstractDecimal{P}
    value::Int128
    precision::UInt8
    
    function Decimal128{P}(value::Integer) where P
        new{P}(Int128(value), UInt8(P))
    end
end

"""
    float32(obj::T) where {T <: AbstractDecimal}

Converts a fixed-precision decimal number to `Float32`.

## Arguments
- `obj::T`: An object of type `AbstractDecimal`

## Returns
- `Float32`: The value converted to `Float32`
"""
function float32(obj::T) where {T <: AbstractDecimal}
    return Float32(obj.value) / Float32(10^obj.precision)
end

"""
    float64(obj::T) where {T <: AbstractDecimal}

Converts a fixed-precision decimal number to `Float64`.

## Arguments
- `obj::T`: An object of type `AbstractDecimal`

## Returns
- `Float64`: The value converted to `Float64`
"""
function float64(obj::T) where {T <: AbstractDecimal}
    return Float64(obj.value) / Float64(10^obj.precision)
end

"""
    DateTime64{P}

Structure for representing DateTime with precision for seconds.
Note that DateTime container can store only milliseconds precision.

## Fields
- `value::DateTime`: The date and time value
- `precision::UInt8`: The precision (number of decimal places for seconds)

## Constructor
    DateTime64{P}(value::DateTime) where P

Creates a new `DateTime64` instance with the given value and precision.
"""
struct DateTime64{P}
    value::DateTime
    precision::UInt8

    function DateTime64{P}(value::DateTime) where P
        new{P}(value, UInt8(P))
    end
end

"""
    NanoDate64{P}

Structure for representing a NanoDate with precision for seconds.
Note that NanoDate container can store only nanoseconds precision.

## Fields
- `value::NanoDate`: The date value with nanosecond precision
- `precision::UInt8`: The precision (number of decimal places for seconds)

## Constructor
    NanoDate64{P}(value::NanoDate) where P

Creates a new `NanoDate64` instance with the given value and precision.
"""
struct NanoDate64{P}
    value::NanoDate
    precision::UInt8

    function NanoDate64{P}(value::NanoDate) where P
        new{P}(value, UInt8(P))
    end
end

"""
    get_unsigned_leb128(data::Vector{UInt8}, offset::Int) -> Tuple{Int64, Int}

Read an unsigned LEB128 encoded integer from the given data starting at the specified offset.

## Arguments
- `data::Vector{UInt8}`: The input data.
- `offset::Int`: The starting offset in the data.

## Returns
- `Tuple{UInt64, Int}`: The decoded value and the number of bytes read.

## Throws
- `RowBinarySyntaxError`: If there are not enough bytes to read or if the LEB128 is too long.
"""
function get_unsigned_leb128(data::Vector{UInt8}, offset::Int)::Tuple{Int64, Int}
    value::UInt64 = 0
    shift::Int = 0
    current_offset::Int = offset

    while true
        if current_offset > length(data)
            throw(RowBinarySyntaxError("Not enough bytes to read LEB128", ArgumentError("Insufficient data")))
        end

        byte::UInt8 = data[current_offset]
        value |= (UInt64(byte & 0x7f) << shift)

        current_offset += 1

        if (byte & 0x80) == 0
            break
        end

        shift += 7
        if shift > 63
            throw(RowBinarySyntaxError("LEB128 is too long", OverflowError("LEB128 exceeds 64 bits")))
        end
    end

    return Int(value), current_offset - offset
end

"""
    union_has_nothing(u::Union) -> Bool

Check if the union type `u` contains the type `Nothing`.

## Arguments
- `u::Union`: The union type to check.

## Returns
- `Bool`: Returns `true` if `u` contains `Nothing`; otherwise, returns `false`.
"""
function union_has_nothing(u::Union)
    if u.a == Nothing || u.b == Nothing
        return true
    elseif !(u.b isa Union)
        return false
    else
        return union_has_nothing(u.b)
    end
end

"""
    parse_type(::Type{T}, data::Vector{UInt8}, offset::Int) where T -> Tuple{Any, Int}

Parse a value of type T from the given data starting at the specified offset.

## Arguments
- `::Type{T}`: The type to parse.
- `data::Vector{UInt8}`: The input data.
- `offset::Int`: The starting offset in the data.

## Returns
- `Tuple{Any, Int}`: The parsed value and the new offset.

## Throws
- `RowBinarySyntaxError`: If an unsupported type is encountered or parsing error.
"""
function parse_type(::Type{T}, data::Vector{UInt8}, offset::Int) where T
    if T <: Integer
        val = reinterpret(T, data[offset:offset+sizeof(T)-1])[1]
        return val, offset + sizeof(T)
    elseif T <: AbstractFloat
        val = reinterpret(T, data[offset:offset+sizeof(T)-1])[1]
        return val, offset + sizeof(T)
    elseif T == Bool
        val = data[offset] != 0
        return val, offset + 1
    elseif T == String
        str_len, bytes_read = get_unsigned_leb128(data, offset)
        offset += bytes_read
        val = String(data[offset:offset+str_len-1])
        return val, offset + str_len
    elseif T == Date
        days_since_epoch = reinterpret(UInt16, data[offset:offset+1])[1]
        return Date(1970, 1, 1) + Day(days_since_epoch), offset + 2
    elseif T == DateTime
        timestamp = reinterpret(Int32, data[offset:offset+3])[1]
        return DateTime(1970, 1, 1) + Second(timestamp), offset + 4
    elseif T == NanoDate
        timestamp = reinterpret(Int32, data[offset:offset+3])[1]
        return NanoDate(1970, 1, 1) + Nanosecond(timestamp * 1_000_000_000), offset + 4
    elseif T <: DateTime64
        timestamp = reinterpret(Int64, data[offset:offset+7])[1]
        precision = T.parameters[1] - 6
        if precision < 0
            timestamp *= 10 ^ abs(precision)
        elseif precision > 0
            timestamp = timestamp ÷ 10 ^ precision
        end
        return T(DateTime(1970, 1, 1) + Microsecond(timestamp)), offset + 8
    elseif T <: NanoDate64
        timestamp = reinterpret(Int64, data[offset:offset+7])[1]
        precision = T.parameters[1] - 9
        if precision < 0
            timestamp *= 10 ^ abs(precision)
        elseif precision > 0
            timestamp = timestamp ÷ 10 ^ precision
        end
        return T(NanoDate(1970, 1, 1) + Nanosecond(timestamp)), offset + 8
    elseif T == Time
        seconds = reinterpret(Int32, data[offset:offset+3])[1] % 86400  # 86400 seconds in a day
        hours = seconds ÷ 3600
        minutes = (seconds % 3600) ÷ 60
        secs = seconds % 60
        return Time(hours, minutes, secs), offset + 4
    elseif T <: Decimal32
        value = reinterpret(Int32, data[offset:offset+3])[1]
        return T(value), offset + 4
    elseif T <: Decimal64
        value = reinterpret(Int64, data[offset:offset+7])[1]
        return T(value), offset + 8
    elseif T <: Decimal128
        value = reinterpret(Int128, data[offset:offset+15])[1]
        return T(value), offset + 16
    elseif T == UUID
        uuid_bytes = data[offset:offset+15]
        uuid_string = string(
            bytes2hex(reverse(uuid_bytes[5:8])),
            "-",
            bytes2hex(reverse(uuid_bytes[3:4])),
            "-",
            bytes2hex(reverse(uuid_bytes[1:2])),
            "-",
            bytes2hex(reverse(uuid_bytes[15:16])),
            "-",
            bytes2hex(reverse(uuid_bytes[9:14]))
        )
        
        return UUID(uuid_string), offset + 16
    elseif T == IPv4
        ip = join(reverse(data[offset:offset+3]), ".")
        return IPv4(ip), offset + 4
    elseif T == IPv6
        hex_str = bytes2hex(data[offset:offset+15])
        ip = join([hex_str[i:i+3] for i in 1:4:32], ":")
        return IPv6(ip), offset + 16
    elseif typeof(T) == Union && union_has_nothing(T)
        if data[offset] == 0x01  # NULL
            return nothing, offset + 1
        else 
            inner_type = T.b != Nothing ? T.b : T.a 
            return parse_type(inner_type, data, offset + 1)
        end
    elseif T <: Vector
        arr_len, bytes_read = get_unsigned_leb128(data, offset)
        offset += bytes_read
        arr = []
        for _ in 1:arr_len
            val, new_offset = parse_type(eltype(T), data, offset)
            push!(arr, val)
            offset = new_offset
        end
        return arr, offset
        elseif T <: Tuple
        tuple_vals = []
        for type in T.types
            val, new_offset = parse_type(type, data, offset)
            push!(tuple_vals, val)
            offset = new_offset
        end
        return Tuple(tuple_vals), offset
    elseif T <: Dict
        map_size, bytes_read = get_unsigned_leb128(data, offset)
        offset += bytes_read
        dict = Dict{keytype(T), valtype(T)}()
        for _ in 1:map_size
            key, new_offset = parse_type(keytype(T), data, offset)
            offset = new_offset
            value, new_offset = parse_type(valtype(T), data, offset)
            offset = new_offset
            dict[key] = value
        end
        return dict, offset
    else
        error("Unsupported type: $T")
    end
end

"""
    parse_rowbinary(::Type{T}, data::Vector{UInt8}) where T -> T

Parse RowBinary data into a struct of type T.

## Arguments
- `::Type{T}`: The type of the struct to parse into.
- `data`: The input data, either as a Vector{UInt8} or an AbstractString.

## Returns
- An instance of type T with parsed values.

## Throws
- `RowBinarySyntaxError`: If parsing fails due to incorrect syntax or any other error.

## Examples

```julia-repl
julia> struct Person
           name::String
           age::Int64
       end

julia> data = UInt8[0x05, 0x41, 0x6c, 0x69, 0x63, 0x65, 0x1e, 0x00, 0x00, 0x00, 
                    0x00, 0x00, 0x00, 0x00]

julia> result = parse_rowbinary(Person, data)
Person("Alice", 30)
```
"""
function parse_rowbinary end

function parse_rowbinary(::Type{T}, data::Vector{UInt8})::T where T
    try
        offset = 1
        values = []
        for field in fieldnames(T)
            field_type = fieldtype(T, field)
            value, new_offset = parse_type(field_type, data, offset)
            push!(values, value)
            offset = new_offset
        end
        return T(values...)
    catch e
        throw(RowBinarySyntaxError("Failed to parse RowBinary data", e))
    end
end

end
