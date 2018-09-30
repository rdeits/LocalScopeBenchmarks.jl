module LocalScopeBenchmarks

import BenchmarkTools
using MacroTools: MacroTools, postwalk, @capture
using OrderedCollections: OrderedDict

function collect_symbols(expr)
    assignments = OrderedDict{Symbol, Expr}()
    postwalk(expr) do x
        if x isa Symbol
            assignments[x] = Expr(:$, x)
        end
    end
    assignments
end

function parse_setup(setup::Expr)
    assignments = OrderedDict()
    postwalk(setup) do x
        if @capture(x, _a = _b)
            assignments[a] = b
        end
    end
    assignments
end

function lower_setup(assignments::AbstractDict)
    Expr(:block, [Expr(:(=), k, v) for (k, v) in assignments]...)
end

function parse_params(kwargs)
    params_dict = OrderedDict((@assert x.head == :kw; x.args[1] => x.args[2]) for x in kwargs)
end

function lower_params(params::AbstractDict)
    [Expr(:kw, k, v) for (k, v) in params]
end

function interpolate_locals_into_setup(args...)
    core, kwargs = BenchmarkTools.prunekwargs(args...)
    params = parse_params(kwargs)
    setup_assignments = parse_setup(get(() -> Expr(:block), params, :setup))
    local_assignments = collect_symbols(core)
    setup = merge(local_assignments, setup_assignments)
    params[:setup] = lower_setup(setup)
    core, lower_params(params)
end

macro benchmark(args...)
    core, params = interpolate_locals_into_setup(args...)
    quote
        BenchmarkTools.@benchmark($(core), $(params...))
    end
end

macro btime(expr, args...)
    core, params = interpolate_locals_into_setup(args...)
    quote
        BenchmarkTools.@btime($(core), $(params...))
    end
end

macro belapsed(expr, args...)
    core, params = interpolate_locals_into_setup(args...)
    quote
        BenchmarkTools.@belapsed($(core), $(params...))
    end
end

end
