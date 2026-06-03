function empty_results_dataframe()
    return DataFrame(
        n=Int[],
        d=Int[],
        p=Int[],
        slopes=String[],
        slopelengths=String[],
        values=String[],
        slopesbefore=String[],
        polystr=String[]
    )
end

function update_results!(df::DataFrame, n, d, p, np, f)
    if nrow(df) > 0
        existing = df[
            (df.n .== n) .&
            (df.d .== d) .&
            (df.p .== p) .&
            (df.values .== string(np.values)), :
        ]
        if nrow(existing) > 0
            return df
        end
    end

    row = Dict(
        "n" => n,
        "d" => d,
        "p" => p,
        "slopes" => string(np.slopes),
        "slopelengths" => string(np.slopelengths),
        "values" => string(np.values),
        "slopesbefore" => string(np.slopesbefore),
        "polystr" => string(f)
    )

    println("Found new Newton polygon:")
    println("$np")
    push!(df, row)

    return df
end

update_df(df::DataFrame, n, d, p, np, f, push_to_supabase=false) = update_results!(df, n, d, p, np, f)

function derham_S(n, d; algorithm=:default)
    if algorithm == :varbyvar
        return [n - 1]
    elseif d < n
        return collect(0:min(d - 1, 2))
    else
        return collect(0:n - 1)
    end
end
