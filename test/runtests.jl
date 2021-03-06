using Test
using LocalScopeBenchmarks
using BenchmarkTools
using Statistics

function judge_loosely(t1, t2)
    judge(ratio(median(t1), median(t2)), time_tolerance=0.2)
end

global_x = 1.0

@testset "LocalScopeBenchmarks" begin
    @testset "Basic benchmarks" begin
        x = 1.0
        t1 = @benchmark(sin($x))
        t2 = @localbenchmark(sin(x))
        j = judge_loosely(t1, t2)
        @show j
        @test isinvariant(j)

        t1 = @benchmark($sin($x))
        t2 = @localbenchmark(sin(x))
        j = judge_loosely(t1, t2)
        @show j
        @test isinvariant(j)

        f = sin
        x = 1.0
        t1 = @benchmark($f($x))
        t2 = @localbenchmark(f(x))
        j = judge_loosely(t1, t2)
        @show j
        @test isinvariant(j)
    end

    @testset "Benchmarks with setup" begin
        @testset "Single setup" begin
            t1 = @benchmark sin(x) setup=(x = 2.0)
            t2 = @localbenchmark sin(x) setup=(x = 2.0)
            j = judge_loosely(t1, t2)
            @show j
            @test isinvariant(j)
        end

        @testset "Multiple setups" begin
            t1 = @benchmark atan(x, y) setup=(x = 2.0; y = 1.5)
            t2 = @localbenchmark atan(x, y) setup=(x = 2.0; y = 1.5)
            j = judge_loosely(t1, t2)
            @show j
            @test isinvariant(j)
        end

        @testset "Setups override local vars" begin
            x = 1.0
            @localbenchmark (@assert x == 2.0) setup=(x = 2.0) evals=1
        end

        @testset "Mixed setup and local vars" begin
            x = 1.0
            t1 = @benchmark atan($x, y) setup=(y = 2.0)
            t2 = @localbenchmark atan(x, y) setup=(y = 2.0)
            j = judge_loosely(t1, t2)
            @show j
            @test isinvariant(j)
        end
    end

    @testset "Additional kwargs" begin
        @testset "evals kwarg" begin
            x = 1.0
            t1 = @benchmark sin($x) evals=5
            t2 = @localbenchmark sin(x) evals=5
            j = judge_loosely(t1, t2)
            @show j
            @test isinvariant(j)
        end

        @testset "evals and setup kwargs" begin
            t1 = @benchmark sin(x) setup=(x = 2.0) evals=5
            t2 = @localbenchmark sin(x) setup=(x = 2.0) evals=5
            j = judge_loosely(t1, t2)
            @show j
            @test isinvariant(j)
        end
    end

    @testset "Test that local benchmarks are faster than globals" begin
        t1 = @benchmark sin(global_x) evals=5  # note the lack of $
        t2 = @localbenchmark sin(global_x) evals=5
        j = judge_loosely(t1, t2)
        @show j
        @test isregression(j)
    end

    @testset "Other macros" begin
        x = 1.0
        @localbtime sin(x)
        @localbelapsed sin(x)
    end

    @testset "Interpolated values" begin
        t1 = @benchmark sum($(rand(1000)))
        t2 = @localbenchmark sum($(rand(1000)))
        j = judge_loosely(t1, t2)
        @show j
        @test isinvariant(j)
    end
end
