function cpu_example_fast_random(n, d, p, N, df)
    S = derham_S(n, d)
    l = ReentrantLock()

    Threads.@threads for _ in 1:N
        f = DeRham.random_hypersurface(n, d, p)
        np = DeRham.newton_polygon(f, S=S, fastevaluation=true, algorithm=:depthfirst)

        if np != false
            @lock l begin
                update_df(df, n, d, p, np, f)
            end
        end
    end

    return df
end

function cpu_vector_fast_random(n, d, p, N, df)
    S = derham_S(n, d)

    for _ in 1:N
        f = DeRham.random_hypersurface(n, d, p)
        np = DeRham.newton_polygon(f, S=S, fastevaluation=true)

        if np != false
            update_df(df, n, d, p, np, f)
        end
    end

    return df
end

function isFSplit(p, poly)
    return !inPowerOfVariableIdeal(p, p, poly^(p - 1))
end

function inPowerOfVariableIdeal(p, m, f)
    f == zero(f) && return true

    for i in 1:length(f)
        ev = Oscar.exponent_vector(f, i)

        if all(ev .< m)
            return false
        end
    end

    return true
end

function cpu_vector_fast_random_K3(n, d, p, N, df)
    S = derham_S(n, d)
    i = 1

    while i <= N
        f = DeRham.random_hypersurface(n, d, p)

        if isFSplit(p, f)
            continue
        end

        println("Found non-F-split example!")
        np = DeRham.newton_polygon(f, S=S, fastevaluation=true, algorithm=:depthfirst, use_threads=true)
        println("Completed Zeta function.")

        if np != false
            update_df(df, n, d, p, np, f)
        end

        i += 1
    end

    return df
end

function cpu_smooth_distributed(n, d, p, N, df)
    if nprocs() == 1
        addprocs()
    end

    for pid in workers()
        Distributed.remotecall_eval(Main, pid, :(using DeRham, NewtonExperiments))
    end

    S = [n - 1]
    results = Distributed.pmap(1:N) do _
        f = NewtonExperiments.find_nsmooth(n, d, p, 1)[1]
        np = DeRham.newton_polygon(f, S=S, fastevaluation=true, algorithm=:varbyvar)
        return (np, f)
    end

    for (np, f) in results
        update_df(df, n, d, p, np, f)
    end

    return df
end

function gpu_smooth_distributed(n, d, p, N, df)
    if nprocs() == 1
        addprocs()
    end

    for pid in workers()
        Distributed.remotecall_eval(Main, pid, :(using DeRham, NewtonExperiments))
    end

    S = [n - 1]
    results = Distributed.pmap(1:N) do _
        f = NewtonExperiments.find_nsmooth(n, d, p, 1)[1]
        np = DeRham.newton_polygon(f, S=S, fastevaluation=true, algorithm=:varbyvar, use_gpu=true)
        return (np, f)
    end

    for (np, f) in results
        update_df(df, n, d, p, np, f)
    end

    return df
end

function all_monomials(n, d, p)
    exp_vecs = DeRham.gen_exp_vec(n, d)
    tuples = collect(Iterators.product(0:p - 1, exp_vecs))
    return tuples[:]
end

function random_monomial(R, p, exp_vecs, context)
    i = rand(1:length(exp_vecs))
    F = base_ring(R)
    push_term!(context, F(rand(0:p - 1)), exp_vecs[i])
    return finish(context)
end

function cpu_example_fast_example(n, d, p, N, f, df; skip_single_monomials=false)
    R = parent(f)
    F = base_ring(R)
    exp_vecs = DeRham.gen_exp_vec(n, d)
    S = derham_S(n, d)
    l = ReentrantLock()
    nT = Threads.nthreads()
    ctx_channel = Channel{MPolyBuildCtx}(nT)

    for _ in 1:nT
        put!(ctx_channel, MPolyBuildCtx(R))
    end

    function run_example(g)
        np = DeRham.newton_polygon(g, S=S, fastevaluation=true, algorithm=:depthfirst)

        if np != false
            @lock l begin
                update_df(df, n, d, p, np, g)
            end
        end
    end

    nMons = length(exp_vecs) * p

    if nMons < N
        if !skip_single_monomials
            println("N=$N exceeds the number of monomials of degree $d in $n variables. Computing f + mon for all such `mon`")
            Threads.@threads for (coef, exp_vec) in all_monomials(n, d, p)
                ctx = take!(ctx_channel)
                push_term!(ctx, F(coef), exp_vec)
                mon = finish(ctx)
                put!(ctx_channel, ctx)
                run_example(f + mon)
            end
        end

        if nMons^2 < N
            println("N is more than the number of pairs of monomials. This experiment only considers random pairs of monomials, so this test is suboptimal.")
        end

        println("Randomly trying pairs of monomials.")
        Threads.@threads for _ in 1:N
            ctx = take!(ctx_channel)
            mon1 = random_monomial(R, p, exp_vecs, ctx)
            mon2 = random_monomial(R, p, exp_vecs, ctx)
            put!(ctx_channel, ctx)
            run_example(f + mon1 + mon2)
        end
    else
        println("Randomly trying monomials.")
        Threads.@threads for _ in 1:N
            ctx = take!(ctx_channel)
            mon = random_monomial(R, p, exp_vecs, ctx)
            put!(ctx_channel, ctx)
            run_example(f + mon)
        end
    end

    return df
end

function cpu_vector_fast_example(n, d, p, N, f, df; skip_single_monomials=false)
    R = parent(f)
    F = base_ring(R)
    exp_vecs = DeRham.gen_exp_vec(n, d)
    S = derham_S(n, d)
    ctx = MPolyBuildCtx(R)

    function run_example(g)
        np = DeRham.newton_polygon(g, S=S, fastevaluation=true, algorithm=:depthfirst, use_threads=true)

        if np != false
            update_df(df, n, d, p, np, g)
        end
    end

    nMons = length(exp_vecs) * p

    if nMons < N
        if !skip_single_monomials
            println("N=$N exceeds the number of monomials of degree $d in $n variables. Computing f + mon for all such `mon`")
            for (coef, exp_vec) in all_monomials(n, d, p)
                push_term!(ctx, F(coef), exp_vec)
                mon = finish(ctx)
                run_example(f + mon)
            end
        end

        if nMons^2 < N
            println("N is more than the number of pairs of monomials. This experiment only considers random pairs of monomials, so this test is suboptimal.")
        end

        println("Randomly trying pairs of monomials.")
        for _ in 1:N
            mon1 = random_monomial(R, p, exp_vecs, ctx)
            mon2 = random_monomial(R, p, exp_vecs, ctx)
            run_example(f + mon1 + mon2)
        end
    else
        println("Randomly trying monomials.")
        for _ in 1:N
            mon = random_monomial(R, p, exp_vecs, ctx)
            run_example(f + mon)
        end
    end

    return df
end

function cpu_vector_fast_weighted_example(n, d, p, N, f, df; num_monomials=1, nonzero_weights=false)
    R = parent(f)
    exp_vecs = DeRham.gen_exp_vec(n, d)
    S = derham_S(n, d)
    ctx = MPolyBuildCtx(R)

    function run_example(g)
        np = DeRham.newton_polygon(g, S=S, fastevaluation=true, algorithm=:depthfirst, use_threads=true)

        if np != false
            update_df(df, n, d, p, np, g)
        end
    end

    nMons = length(exp_vecs) * p
    nWeights = p^length(terms(f))
    nExamples = nMons * nWeights

    if nExamples < N
        println("Warning: N=$N exceeds the number of monomial-weight combinations of degree $d in $n variables. Consider using a different test that enumerates these combinations.")
    end

    println("Randomly scaling monomials of f by weights and adding monomials.")
    for _ in 1:N
        ts = terms(f)
        weights = nonzero_weights ? rand(1:p - 1, length(ts)) : rand(0:p - 1, length(ts))
        ff = sum(weights .* ts)

        for _ in 1:num_monomials
            mon = random_monomial(R, p, exp_vecs, ctx)
            ff = f + mon
        end

        run_example(ff)
    end

    return df
end

function partitions_leq(n, k)
    function padwithzeros!(partition, size)
        padding_length = size - length(partition)
        if 0 < padding_length
            append!(partition, zeros(eltype(partition), padding_length))
        end
    end

    result = collect.(Oscar.partitions(n, 1))
    padwithzeros!.(result, k)

    for i in 2:k
        new_partitions = collect.(Oscar.partitions(n, i))
        padwithzeros!.(new_partitions, k)
        result = vcat(result, new_partitions)
    end

    return result
end

function monomial_symmetric_polynomial(R, partition; ctx=nothing)
    vars = gens(R)
    l = length(partition)
    n = length(vars)

    n != l && throw(ArgumentError("Need $l variables for partition $partition but have $n."))

    if ctx === nothing
        ctx = MPolyBuildCtx(R)
    end

    for ptn in Combinatorics.multiset_permutations(partition, l)
        push_term!(ctx, one(base_ring(R)), ptn)
    end

    return finish(ctx)
end

function all_monomial_symmetric_polynomials(n, d, p)
    R, _ = polynomial_ring(GF(p), n)
    partitions = partitions_leq(d, n)
    ctx = MPolyBuildCtx(R)

    return monomial_symmetric_polynomial.((R,), partitions, ctx=ctx)
end

function all_tuples_of_length(n, p)
    return collect(Iterators.product(fill(0:p - 1, n)...))[:]
end

function cpu_vector_fast_symmetric(n, d, p, N, df)
    symmpolys = all_monomial_symmetric_polynomials(n, d, p)
    S = derham_S(n, d)

    function run_example(g)
        np = DeRham.newton_polygon(g, S=S, fastevaluation=true, algorithm=:depthfirst, use_threads=true)

        if np != false
            update_df(df, n, d, p, np, g)
        end
    end

    l = length(symmpolys)
    nExamples = 2 * p^(l - 1)

    if nExamples < N
        println("N=$N exceeds the number of symmetric polynomials of degree $d in $n variables. Computing the newton polygon for all such examples")

        for weights in all_tuples_of_length(l - 1, p)
            interesting_term = sum(weights .* symmpolys[2:end])
            run_example(interesting_term)
            run_example(symmpolys[1] + interesting_term)
        end
    else
        println("Randomly trying linear combinations of symmetric polynomials.")
        for _ in 1:N
            weights = rand(0:p - 1, l)
            ff = sum(weights .* symmpolys)
            run_example(ff)
        end
    end

    return df
end
