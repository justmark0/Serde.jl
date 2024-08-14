module RowbinaryTypes

export 
    AbstractDecimal,
    Decimal32,
    Decimal64,
    Decimal128,
    DateTime64,
    NanoDate64,
    float32,
    float64,
    union_has_nothing

using Dates
using NanoDates

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

end