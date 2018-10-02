# LocalScopeBenchmarks.jl

[![Build Status](https://travis-ci.org/rdeits/LocalScopeBenchmarks.jl.svg?branch=master)](https://travis-ci.org/rdeits/LocalScopeBenchmarks.jl)
[![codecov.io](https://codecov.io/github/rdeits/LocalScopeBenchmarks.jl/coverage.svg?branch=master)](https://codecov.io/github/rdeits/LocalScopeBenchmarks.jl?branch=master)

**tl;dr:** Tired of adding `$` everywhere when you `@benchmark` or `@btime`? Try `@localbtime f(x)` instead of `@btime f($x)`.

## Introduction

[BenchmarkTools.jl](https://github.com/JuliaCI/BenchmarkTools.jl) is an amazingly useful package for benchmarking [Julia](https://julialang.org/) code. But it does have one notable gotcha: the expression being benchmarked is run at *global* scope, so any variables it references are by necessity global variables. Julia enthusiasts may recall that the very first Julia performance tip is to [avoid non-`const` global variables](https://docs.julialang.org/en/stable/manual/performance-tips/#Avoid-global-variables-1) because their type can change at any time and therefore can't be relied upon by the compiler. The result is that naively using `BenchmarkTools.jl` often results in benchmarks that appear to run much slower than they should due to the performance cost of accessing globals.

For example, a common benchmarking mistake looks like:

```julia
julia> using BenchmarkTools

julia> x = 1.0
1.0

julia> @btime sin(x)
  18.011 ns (1 allocation: 16 bytes)
```

18 nanoseconds is a bit slow, and we have an unexpected 16 bytes of heap memory allocation.

The solution is easy, and is explained in the [BenchmarkTools.jl manual](https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/doc/manual.md#interpolating-values-into-benchmark-expressions): you just have to interpolate the *value* of `x` into the benchmark expression rather than force it to be looked up as a global variable:

```julia
julia> @btime sin($x)
  7.059 ns (0 allocations: 0 bytes)
0.8414709848078965
```

much faster, and no unexpected memory allocation. By interpolating `$x`, we get a result which is representative of how fast `sin` would behave for an input of this type inside a function, which is where it's almost always going to be found.

This interpolation trick is easy to do, but I've found it consistently annoying, and it's caused an impressive amount of confusion (kudos to `@NiclasMattsson` on Discourse for finding most of these):

* https://discourse.julialang.org/t/trig-functions-very-slow/15335/54
* https://discourse.julialang.org/t/another-blas-and-julia-comparison/15411/2
* https://discourse.julialang.org/t/allocation-by-staticarrays-in-anonymous-function-macro/14774/2
* https://discourse.julialang.org/t/how-to-optimise-and-be-faster-than-java/14457/22
* https://discourse.julialang.org/t/interval-arithmetic-computation-time/14633/14
* https://discourse.julialang.org/t/with-missings-julia-is-slower-than-r/11838/9
* https://discourse.julialang.org/t/vector-of-matrices-vs-multidimensional-arrays/9602/3
* https://discourse.julialang.org/t/spurious-allocation/3751/7
* https://discourse.julialang.org/t/improve-the-performance-of-multiplication-of-an-arbitrary-number-of-matrices/10835/19
* https://discourse.julialang.org/t/a-generator-with-two-for-keywords-is-slow/7407/5

## There Has To Be a Better Way!

Enter `LocalScopeBenchmarks.jl`. This package tries to do exactly one thing: save you from having to remember to add `$` all over the place when benchmarking. Observe:

```julia
julia> using LocalScopeBenchmarks

julia> x = 1
1

julia> @localbtime sin(x)
  13.108 ns (0 allocations: 0 bytes)
0.8414709848078965
```

We got the same measurement as `@btime sin($x)` without having to add a `$`.

### Installation

```julia
using Pkg
Pkg.add("LocalScopeBenchmarks")
```

or just press `]` at the Julia REPL and then enter `add LocalScopeBenchmarks`

### Usage

```julia
using LocalScopeBenchmarks
```

This package provides `@localbtime`, `@localbenchmark`, and `@localbelapsed`, analogous to `@btime`, `@benchmark`, and `@belapsed` from BenchmarkTools.jl. Each should support the same inputs and return the same types as their BenchmarkTools.jl versions (in fact, each of them is just a thin wrapper around the existing BenchmarkTools macros). The only change is that the `@local*` versions try to interpolate local variables into the benchmarked expression rather than treating those variables as global.

Since we're just using BenchmarkTools under the hood, the `setup` and `evals` keyword arguments work as normal:

```julia
julia> x = 1.0
1.0

julia> @localbtime f(x) setup=(f = sin)
  6.791 ns (0 allocations: 0 bytes)
```

```julia
julia> @localbtime x^2 evals=100
  0.290 ns (0 allocations: 0 bytes)
```

You can also still interpolate values into the expression with `$` if you really want:

```julia
# Includes the time spent calling `rand(1000)`
julia> @localbtime sum(rand(1000))
  1.084 μs (1 allocation: 7.94 KiB)
```

```julia
# Interpolates the *value* of `rand(1000)` so that it's not
# computed inside the benchmark:
julia> @localbtime sum($(rand(1000)))
  69.160 ns (0 allocations: 0 bytes)
```

