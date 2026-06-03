const EXPERIMENTS = Dict{Symbol, Function}(
    :cpu_example_fast_random => cpu_example_fast_random,
    :cpu_vector_fast_random => cpu_vector_fast_random,
    :cpu_vector_fast_random_K3 => cpu_vector_fast_random_K3,
    :cpu_smooth_distributed => cpu_smooth_distributed,
    :gpu_smooth_distributed => gpu_smooth_distributed,
    :gpu_random_hypersurface => gpu_random_hypersurface_experiment,
    :gpu_random_cubic_fourfold => (n, d, p, N, df; kwargs...) -> gpu_random_cubic_fourfold_experiment(p, N, df; n=n, d=d, kwargs...)
)

function run_experiment(experiment::Function, n, d, p, N, df=empty_results_dataframe(); kwargs...)
    return experiment(n, d, p, N, df; kwargs...)
end

function run_experiment(experiment::Symbol, n, d, p, N, df=empty_results_dataframe(); kwargs...)
    haskey(EXPERIMENTS, experiment) || throw(ArgumentError("Unknown experiment: $experiment"))
    return run_experiment(EXPERIMENTS[experiment], n, d, p, N, df; kwargs...)
end

function run_experiment(experiment::AbstractString, n, d, p, N, df=empty_results_dataframe(); kwargs...)
    return run_experiment(Symbol(experiment), n, d, p, N, df; kwargs...)
end

function run_supabase_pipeline(;
    url=get(ENV, "SUPABASE_URL", nothing),
    key=get(ENV, "SUPABASE_KEY", nothing),
    n=6,
    d=3,
    p=13,
    N=1,
    table="n$(n)_d$(d)_np",
    heights_table="heights",
    experiment=:gpu_random_hypersurface,
    save_csv=true,
    csv_path="$(table).csv",
    push_heights=false,
    heights=DataFrame(id=collect(1:11), num=zeros(Int, 11)),
    kwargs...
)
    url === nothing && error("Set SUPABASE_URL or pass url=...")
    key === nothing && error("Set SUPABASE_KEY or pass key=...")

    start_time = time()
    client = SupabaseClient(url, key)

    println("Number of threads: $(Threads.nthreads())")
    println("\nFetching existing table...")
    df_old = fetch_table(client, table)
    println("Loaded $(nrow(df_old)) rows.\n")

    old_count = nrow(df_old)

    println("Running experiment...")
    @time df = run_experiment(experiment, n, d, p, N, df_old; kwargs...)

    if save_csv
        println("Saving full table to CSV: $csv_path")
        CSV.write(csv_path, df)
    end

    println("Pushing new rows to Supabase...")
    newrows = df[old_count + 1:end, :]
    for row in eachrow(newrows)
        row_dict = Dict(names(newrows) .=> values(row))
        push_row(client, table, row_dict)
    end

    if push_heights
        println("Pushing new heights to Supabase...")
        add_heights_patch!(client, heights, heights_table, false)
    end

    println("Done.")
    println("Time taken: $(time() - start_time) seconds")

    return df[(df.n .== n) .& (df.d .== d) .& (df.p .== p), :]
end
