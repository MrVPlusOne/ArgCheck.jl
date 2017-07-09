using ArgCheck
using Base.Test

macro catch_exception_object(code)
    esc(quote
        err = try
            $code
            nothing
        catch e
            e
        end
        if err == nothing
            error("Expected exception, got nothing.")
        end
        err
    end
    )
end

import ArgCheck: is_comparison_call, canonicalize
@testset "helper functions" begin
    @test is_comparison_call(:(1==2))
    @test is_comparison_call(:(f(2x) + 1 ≈ f(x)))
    @test is_comparison_call(:(<(2,3)))
    @test !is_comparison_call(:(f(1,1)))

    ex = :(x1 < x2)
    @test canonicalize(ex) != ex
    @test canonicalize(ex) == Expr(:comparison, :x1, :(<), :x2)

    ex = :(det(x) < y < z)
    @test canonicalize(ex) == ex
end

@testset "Chained comparisons" begin
    #6
    x=y=z = 1
    @test x == y == z
    @argcheck x == y == z
    z = 2
    @test_throws ArgumentError @argcheck x == y == z

    @test_throws ArgumentError @argcheck 1 ≈ 2 == 2
    @argcheck 1 == 1 ≈ 1 < 2 > 1.2
    @test_throws DimensionMismatch @argcheck 1 < 2 ==3 DimensionMismatch 
end

@testset "@argcheck" begin
    @test_throws ArgumentError @argcheck false
    @argcheck true

    x = 1
    @test_throws ArgumentError (@argcheck x > 1)
    @test_throws ArgumentError @argcheck x > 1 "this should not happen"
    @argcheck x>0 # does not throw
    
    n =2; m=3
    @test_throws DimensionMismatch (@argcheck n==m DimensionMismatch)
    @argcheck n==n DimensionMismatch
    
    denominator = 0
    @test_throws DivideError (@argcheck denominator != 0 DivideError())
    @argcheck 1 !=0 DivideError()

end

# exotic cases
f() = false
t() = true
@argcheck t()
@test_throws ArgumentError @argcheck f()

op() = (x,y) -> x < y
x = 1; y = 2
@argcheck op()(x,y)
@test_throws ArgumentError @argcheck op()(y,x)

immutable MyExoticError <: Exception
    a::Int
    b::Int
end


immutable MyError <: Exception
    msg::String
end

@testset "error message" begin
    x = 1.23455475675
    y = 2.345345345
    # comparison
    err = @catch_exception_object @argcheck x == y MyError
    @test isa(err, MyError)
    msg = err.msg
    @test contains(msg, string(x))
    @test contains(msg, string(y))
    @test contains(msg, "x")
    @test contains(msg, "y")
    @test contains(msg, "==")

    x = 1.2
    y = 1.34
    z = -345.234
    err = @catch_exception_object @argcheck x < y < z
    msg = err.msg
    @test contains(msg, string(z))
    @test contains(msg, string(y))
    @test contains(msg, "y")
    @test contains(msg, "z")
    @test contains(msg, "<")
    @test !contains(msg, string(x))

    err = @catch_exception_object @argcheck false MyExoticError 1 2
    @test err === MyExoticError(1,2)
end
