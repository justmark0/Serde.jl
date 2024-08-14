# Par/ParRowbinary

# using Serde.ext.RowbinaryExt.RowbinaryTypes

@testset verbose = true "ParRowbinary" begin
    @testset "Case №1: Basic Types" begin
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

        data = UInt8[0xd6, 0x18, 0xfc, 0xc0, 0xbd, 0xf0, 0xff, 0x00, 0x36, 0x65, 0xc4, 
         0xff, 0xff, 0xff, 0xff, 0xc8, 0x40, 0x9c, 0x00, 0x5e, 0xd0, 0xb2, 0x00, 0xe4, 
         0x0b, 0x54, 0x02, 0x00, 0x00, 0x00, 0xc3, 0xf5, 0x48, 0x40, 0x90, 0xf7, 0xaa, 
         0x95, 0x09, 0xbf, 0x05, 0x40, 0x11, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x2c, 0x20, 
         0x52, 0x6f, 0x77, 0x62, 0x69, 0x6e, 0x61, 0x72, 0x79, 0x21, 0xef, 0x4d, 0x70, 
         0x47, 0xbf, 0x66]

        parsed = Serde.parse_rowbinary(BasicTypes, data)

        @test parsed.int8 == -42
        @test parsed.int16 == -1000
        @test parsed.int32 == -1000000
        @test parsed.int64 == -1000000000
        @test parsed.uint8 == 200
        @test parsed.uint16 == 40000
        @test parsed.uint32 == 3000000000
        @test parsed.uint64 == 10000000000
        @test parsed.float32 ≈ 3.14f0
        @test parsed.float64 ≈ 2.71828
        @test parsed.string == "Hello, Rowbinary!"
        @test parsed.date == Date(2024, 8, 16)
        @test parsed.datetime == DateTime(2024, 8, 16, 12, 34, 56)
    end

    # @testset "Case №2: Nested Types" begin
    #     struct NestedTypes
    #         array_int32::Vector{Vector{Int32}}
    #         array_string::Vector{String}
    #         tuple_mixed::Tuple{Int32, String, Float64}
    #         dict_string_int::Dict{String, Int32}
    #     end

    #     data = UInt8[0x02, 0x02, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x03, 
    #      0x03, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x03, 
    #      0x01, 0x61, 0x01, 0x62, 0x01, 0x63, 0x2a, 0x00, 0x00, 0x00, 0x06, 0x61, 0x6e, 
    #      0x73, 0x77, 0x65, 0x72, 0x1f, 0x85, 0xeb, 0x51, 0xb8, 0x1e, 0x09, 0x40, 0x03, 
    #      0x03, 0x6f, 0x6e, 0x65, 0x01, 0x00, 0x00, 0x00, 0x03, 0x74, 0x77, 0x6f, 0x02, 
    #      0x00, 0x00, 0x00, 0x05, 0x74, 0x68, 0x72, 0x65, 0x65, 0x03, 0x00, 0x00, 0x00]

    #     parsed = Serde.parse_rowbinary(NestedTypes, data)

    #     @test parsed.array_int32 == [[1, 2], [3, 4, 5]]
    #     @test parsed.array_string == ["a", "b", "c"]
    #     @test parsed.tuple_mixed == (42, "answer", 3.14)
    #     @test parsed.dict_string_int == Dict("one" => 1, "two" => 2, "three" => 3)
    # end

    # @testset "Case №3: Nullable Types" begin
    #     struct NullableTypes
    #         nullable_int::Union{Nothing, Int32}
    #         nullable_string::Union{Nothing, String}
    #         nullable_float::Union{Nothing, Float64}
    #         array_nullable::Vector{Union{Nothing, Int32}}
    #     end

    #     data = UInt8[0x01, 0x00, 0x08, 0x4e, 0x6f, 0x74, 0x20, 0x4e, 0x75, 0x6c, 0x6c, 0x00, 0x1f, 0x85, 0xeb, 0x51, 0xb8, 0x1e, 0x09, 0x40, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x03, 0x00, 0x00, 0x00]
    #     parsed = Serde.parse_rowbinary(NullableTypes, data)

    #     @test parsed.nullable_int === nothing
    #     @test parsed.nullable_string == "Not Null"
    #     @test parsed.nullable_float == 3.14
    #     @test parsed.array_nullable == [1, nothing, 3]
    # end

    # @testset "Case №4: Special Types" begin
    #     struct SpecialTypes
    #         decimal32::RowbinaryTypes.Decimal32{2}
    #         decimal64::RowbinaryTypes.Decimal64{3}
    #         decimal128::RowbinaryTypes.Decimal128{4}
    #         datetime64::RowbinaryTypes.DateTime64{6}
    #         ipv4::IPv4
    #         ipv6::IPv6
    #     end

    #     data = UInt8[0x39, 0x30, 0x00, 0x00, 0x4e, 0x61, 0xbc, 0x00, 0x00, 0x00, 0x00, 
    #      0x00, 0x22, 0x09, 0xfb, 0x71, 0x1f, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
    #      0x00, 0x00, 0x00, 0x00, 0x40, 0x7e, 0xa5, 0xae, 0xba, 0xfb, 0x05, 0x00, 0x01, 
    #      0x00, 0xa8, 0xc0, 0x20, 0x01, 0x0d, 0xb8, 0x85, 0xa3, 0x00, 0x00, 0x00, 0x00, 
    #      0x8a, 0x2e, 0x03, 0x70, 0x73, 0x34]

    #     parsed = Serde.parse_rowbinary(SpecialTypes, data)

    #     @test RowbinaryTypes.float64(parsed.decimal32) == 123.45
    #     @test RowbinaryTypes.float64(parsed.decimal64) == 12345.678
    #     @test RowbinaryTypes.float64(parsed.decimal128) == 123456789.1234
    #     @test parsed.datetime64.value == DateTime(2023, 5, 15, 12, 34, 56, 123)
    #     @test parsed.ipv4 == IPv4("192.168.0.1")
    #     @test parsed.ipv6 == IPv6("2001:db8:85a3::8a2e:370:7334")
    # end
end
