# Ser/SerRowbinary

using Serde.ParRowbinary

@testset verbose = true "SerRowbinary" begin
    @testset "Case №1: Basic Types Serialization" begin
        struct BasicTypes
            int8::Int8
            int16::Int16
            int32::Int32
            int64::Int64
            uint8::UInt8
            uint16::UInt16
            uint32::UInt32
            uint64::UInt64
            float32::Float32
            float64::Float64
            string::String
            date::Date
            datetime::DateTime
        end

        obj = BasicTypes(
            -42, -1000, -1000000, -1000000000,
            200, 40000, 3000000000, 10000000000,
            3.14f0, 2.71828,
            "Hello, RowBinary!",
            Date(2024, 8, 16),
            DateTime(2024, 8, 16, 12, 34, 56)
        )

        serialized = Serde.to_rowbinary(obj)

        expected = UInt8[0xd6, 0x18, 0xfc, 0xc0, 0xbd, 0xf0, 0xff, 0x00, 0x36, 0x65, 
             0xc4, 0xff, 0xff, 0xff, 0xff, 0xc8, 0x40, 0x9c, 0x00, 0x5e, 0xd0, 0xb2, 
             0x00, 0xe4, 0x0b, 0x54, 0x02, 0x00, 0x00, 0x00, 0xc3, 0xf5, 0x48, 0x40, 
             0x90, 0xf7, 0xaa, 0x95, 0x09, 0xbf, 0x05, 0x40, 0x11, 0x48, 0x65, 0x6c,
             0x6c, 0x6f, 0x2c, 0x20, 0x52, 0x6f, 0x77, 0x42, 0x69, 0x6e, 0x61, 0x72, 
             0x79, 0x21, 0xef, 0x4d, 0x70, 0x47, 0xbf, 0x66]

        @test serialized == expected
    end

    @testset "Case №2: Serialization with Ignore Field" begin
        struct IgnoreFieldRecord
            id::Int64
            name::String
            ignore_me::String
        end

        Serde.SerRowbinary.ser_ignore_field(::Type{IgnoreFieldRecord}, ::Val{:ignore_me}) = true

        exp_obj = IgnoreFieldRecord(1, "test", "ignore")
        exp_bin = vcat(
            reinterpret(UInt8, [Int64(1)]),
            [0x04],
            Vector{UInt8}("test")
        )
        @test Serde.to_rowbinary(exp_obj) == exp_bin
    end

    @testset "Case №3: Nested Types Serialization" begin
        struct NestedTypes
            array_int32::Vector{Vector{Int32}}
            array_string::Vector{String}
            tuple_mixed::Tuple{Int32, String, Float64}
            dict_string_int::Dict{String, Int32}
        end

        obj = NestedTypes(
            [[1, 2], [3, 4, 5]],
            ["a", "b", "c"],
            (42, "answer", 3.14),
            Dict("1" => 1, "2" => 2, "3" => 3)
        )

        serialized = Serde.to_rowbinary(obj)

        expected = UInt8[0x02, 0x02, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 
             0x03, 0x03, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 
             0x00, 0x03, 0x01, 0x61, 0x01, 0x62, 0x01, 0x63, 0x2a, 0x00, 0x00, 0x00, 
             0x06, 0x61, 0x6e, 0x73, 0x77, 0x65, 0x72, 0x1f, 0x85, 0xeb, 0x51, 0xb8, 
             0x1e, 0x09, 0x40, 0x03, 0x01, 0x31, 0x01, 0x00, 0x00, 0x00, 0x01, 0x32, 
             0x02, 0x00, 0x00, 0x00, 0x01, 0x33, 0x03, 0x00, 0x00, 0x00]

        @test serialized == expected
    end

    @testset "Case №4: Nullable Types Serialization" begin
        struct NullableTypes
            nullable_int::Union{Nothing, Int32}
            nullable_string::Union{Nothing, String}
            nullable_float::Union{Nothing, Float64}
            array_nullable::Vector{Union{Nothing, Int32}}
        end

        obj = NullableTypes(
            nothing,
            "Not Null",
            3.14,
            [1, nothing, 3]
        )

        serialized = Serde.to_rowbinary(obj)
        
        expected = UInt8[0x01, 0x00, 0x08, 0x4e, 0x6f, 0x74, 0x20, 0x4e, 0x75, 0x6c, 
             0x6c, 0x00, 0x1f, 0x85, 0xeb, 0x51, 0xb8, 0x1e, 0x09, 0x40, 0x03, 0x00, 
             0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x03, 0x00, 0x00, 0x00]

        @test serialized == expected
    end

    @testset "Case №5: Special Types Serialization" begin
        struct SpecialTypes
            decimal32::ParRowbinary.Decimal32{2}
            decimal64::ParRowbinary.Decimal64{3}
            decimal128::ParRowbinary.Decimal128{4}
            datetime64::ParRowbinary.DateTime64{6}
            ipv4::IPv4
            ipv6::IPv6
            uuid::UUID
        end

        obj = SpecialTypes(
            ParRowbinary.Decimal32{2}(12345),
            ParRowbinary.Decimal64{3}(12345678),
            ParRowbinary.Decimal128{4}(1234567891234),
            ParRowbinary.DateTime64{6}(DateTime(2023, 5, 15, 12, 34, 56, 123)),
            IPv4("192.168.0.1"),
            IPv6("2001:0db8:85a3:0000:0000:8a2e:0370:7334"),
            UUID("f47ac10b-58cc-4372-a567-0e02b2c3d479")
        )

        serialized = Serde.to_rowbinary(obj)

        expected = UInt8[0x39, 0x30, 0x00, 0x00, 0x4e, 0x61, 0xbc, 0x00, 0x00, 0x00, 
             0x00, 0x00, 0x22, 0x09, 0xfb, 0x71, 0x1f, 0x01, 0x00, 0x00, 0x00, 0x00, 
             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x78, 0x7c, 0xa5, 0xae, 0xba, 0xfb, 
             0x05, 0x00, 0x01, 0x00, 0xa8, 0xc0, 0x20, 0x01, 0x0d, 0xb8, 0x85, 0xa3, 
             0x00, 0x00, 0x00, 0x00, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x34, 0x72, 0x43, 
             0xcc, 0x58, 0x0b, 0xc1, 0x7a, 0xf4, 0x79, 0xd4, 0xc3, 0xb2, 0x02, 0x0e, 
             0x67, 0xa5]

        @test serialized == expected
    end
end
