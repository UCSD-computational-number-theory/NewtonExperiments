using NewtonExperiments

function parse_bool(value)
    return lowercase(string(value)) in ("1", "true", "yes", "y")
end

n = parse(Int, get(ENV, "NEWTON_N", "6"))
d = parse(Int, get(ENV, "NEWTON_D", "3"))
p = parse(Int, get(ENV, "NEWTON_P", "13"))
N = parse(Int, get(ENV, "NEWTON_SAMPLES", "1"))
experiment = Symbol(get(ENV, "NEWTON_EXPERIMENT", "gpu_random_hypersurface"))
table = get(ENV, "NEWTON_TABLE", "n$(n)_d$(d)_np")
csv_path = get(ENV, "NEWTON_CSV", "$(table).csv")
save_csv = parse_bool(get(ENV, "NEWTON_SAVE_CSV", "true"))

run_supabase_pipeline(
    n=n,
    d=d,
    p=p,
    N=N,
    experiment=experiment,
    table=table,
    csv_path=csv_path,
    save_csv=save_csv
)
