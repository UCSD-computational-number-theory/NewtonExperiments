#!/usr/bin/env julia
#
# Driver for Table 2 (`table:sparse-surfaces`) of arxiv:2602.24155:
# "Algorithms for degree d surfaces in P^3 over F_p with six terms."
#
# Reproduces both columns per degree:
#   * "ours"  — DeRham depth-first reduction policy (fast evaluation), and
#   * "[CHK]"  — ToricControlledReduction (Costa–Harvey–Kedlaya) via MathResearch.jl.
#
# Grid: surfaces in P^3 (code n = 4), d ∈ {3, 4}, p ∈ {7,11,13,17,19,23,29,31}.
# [CHK] is skipped at p = 7 by design (TCR small-p limit) and degrades to "–"
# wherever the TCR binary is not built (see comparisons/toric_controlled_reduction.jl).
#
# Run single-threaded for the published timing convention:
#
#     julia -t 1 --project=. scripts/run_table2.jl
#
# Timing per cell = one untimed JIT warm-up, then best-of-3 minimum wall clock.
# A gitignored CSV (table2_results.csv) is written next to this script.

using NewtonExperiments
using DeRham
using DataFrames
using CSV
using Random
using Printf

include(joinpath(@__DIR__, "..", "comparisons", "toric_controlled_reduction.jl"))

# Surfaces in P^3 ⟹ 4 variables in this codebase (paper labels this "n=3").
const N        = 4
const DEGREES  = [3, 4]
const PRIMES   = [7, 11, 13, 17, 19, 23, 29, 31]
const MASTER_SEED = 20260605
const CSV_PATH = joinpath(@__DIR__, "table2_results.csv")

# Deterministic, grid-order-independent per-cell RNG so every (d, p) cell always
# yields the same representative six-term surface.
cell_rng(d, p) = MersenneTwister(MASTER_SEED + 1000 * d + p)

fmt_time(x::Missing) = "–"
fmt_time(x::Real)    = @sprintf("%.2f", x)

function run_table2()
    println("="^72)
    println("Table 2 replication — six-term surfaces in P^3  (code n = $N)")
    println("Master seed: $MASTER_SEED")
    println("Grid: d ∈ $(DEGREES), p ∈ $(PRIMES)")
    println("Timing: untimed warm-up, then best-of-3 minimum, single-threaded.")
    println("="^72)

    results = DataFrame(
        d       = Int[],
        p       = Int[],
        n_terms = Int[],
        poly    = String[],
        t_ours  = Float64[],
        t_chk   = Union{Missing,Float64}[],
    )

    for d in DEGREES
        for p in PRIMES
            rng = cell_rng(d, p)
            f = random_six_term_surface(N, d, p; rng=rng)
            nt = length(f)

            @printf("\n[d=%d, p=%2d]  seed=%d  terms=%d\n", d, p, MASTER_SEED + 1000 * d + p, nt)
            println("  f = $f")

            t_ours = time_zeta_depthfirst(f)
            @printf("  ours  = %.4f s\n", t_ours)

            t_chk = time_chk(p, f)
            println("  [CHK] = $(t_chk === missing ? "– (skipped/unavailable)" : @sprintf("%.4f s", t_chk))")

            push!(results, (d, p, nt, string(f), t_ours, t_chk))
        end
    end

    print_table(results)

    CSV.write(CSV_PATH, results)
    println("\nWrote raw results to $CSV_PATH (gitignored).")

    return results
end

# Pretty-print the Table-2 shape: p | (cubic ours, cubic [CHK]) | (quartic ours, quartic [CHK]).
function print_table(results::DataFrame)
    println("\n" * "="^72)
    println("Table 2 — degree-d surfaces in P^3 over F_p, six terms (seconds)")
    println("="^72)
    @printf("%4s | %18s | %18s\n", "", "Cubic (d=3)", "Quartic (d=4)")
    @printf("%4s | %8s %8s | %8s %8s\n", "p", "ours", "[CHK]", "ours", "[CHK]")
    println("-"^50)
    for p in PRIMES
        c = results[(results.d .== 3) .& (results.p .== p), :]
        q = results[(results.d .== 4) .& (results.p .== p), :]
        co = isempty(c) ? "?" : fmt_time(c.t_ours[1])
        cc = isempty(c) ? "?" : fmt_time(c.t_chk[1])
        qo = isempty(q) ? "?" : fmt_time(q.t_ours[1])
        qc = isempty(q) ? "?" : fmt_time(q.t_chk[1])
        @printf("%4d | %8s %8s | %8s %8s\n", p, co, cc, qo, qc)
    end
    println("-"^50)
    println("ours = depth-first reduction policy; [CHK] = ToricControlledReduction.")
    println("\"–\" = [CHK] skipped by design (p=7) or TCR binary unavailable.")
end

# Run when invoked as a script (not when included for its helpers).
if abspath(PROGRAM_FILE) == @__FILE__
    run_table2()
end
