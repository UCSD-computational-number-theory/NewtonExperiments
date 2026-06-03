function gpu_derham_S(n, d; algorithm=:varbyvar)
    return derham_S(n, d; algorithm=algorithm)
end

function gpu_random_hypersurface_experiment(n, d, p, N, df; algorithm=:varbyvar, verbose=0, changef=true, vars_reversed=false, fastevaluation=true, always_use_bigints=false)
    S = gpu_derham_S(n, d; algorithm=algorithm)
    i = 0

    while i < N
        f = DeRham.random_hypersurface(n, d, p)
        np = DeRham.newton_polygon(
            f;
            S=S,
            verbose=verbose,
            changef=changef,
            algorithm=algorithm,
            vars_reversed=vars_reversed,
            fastevaluation=fastevaluation,
            always_use_bigints=always_use_bigints,
            use_gpu=true
        )

        if np != false
            update_df(df, n, d, p, np, f)
            i += 1
        end
    end

    return df
end

function gpu_random_cubic_fourfold_experiment(p, N, df; n=6, d=3, kwargs...)
    return gpu_random_hypersurface_experiment(n, d, p, N, df; kwargs...)
end
