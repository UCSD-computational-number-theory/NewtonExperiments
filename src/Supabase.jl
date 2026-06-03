struct SupabaseClient
    url::String
    key::String
end

function headers(c::SupabaseClient)
    return [
        "apikey" => c.key,
        "Authorization" => "Bearer $(c.key)",
        "Content-Type" => "application/json"
    ]
end

function push_row(c::SupabaseClient, table::String, row::Dict)
    baseurl = "$(c.url)/rest/v1/$table"
    payload = JSON.json(row)

    return HTTP.post(baseurl, headers=headers(c), body=payload)
end

function fetch_table(c::SupabaseClient, table::String)
    resp = nothing
    try
        url = "$(c.url)/rest/v1/$table?select=*"
        resp = HTTP.get(url, headers=headers(c))
    catch e
        println("Error fetching table: $(e)")
        error("Please make the table $(table) first on Supabase.")
    end

    rows = JSON.parse(String(resp.body))

    if length(rows) == 0
        return empty_results_dataframe()
    end

    return DataFrame(rows)
end

function add_heights_patch!(c::SupabaseClient, heights::DataFrame, heights_table::String, atomic::Bool=true)
    rows = [
        Dict("id" => row.id, "num" => row.num)
        for row in eachrow(heights)
        if row.num != 0
    ]

    isempty(rows) && return nothing

    url = "$(c.url)/rest/v1/rpc/add_heights_generic"
    payload = JSON.json(Dict("target_table" => heights_table, "rows" => rows))
    resp = HTTP.post(url, headers=headers(c), body=payload)

    if resp.status >= 300
        error("Supabase RPC failed: $(String(resp.body))")
    end

    heights.num .= 0
    return heights
end
