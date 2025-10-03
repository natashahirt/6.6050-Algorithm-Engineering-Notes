function bucket_sort(input::Vector{Int64}; n_buckets::Int = 5)
    min_val = minimum(input)
    max_val = maximum(input)
    bucket_size = (max_val - min_val) / n_buckets
    bucket_keys = [min_val + (i-1) * bucket_size for i in 1:n_buckets]
    buckets = Dict()
    out = []
    for val in input
        i = 1
        while (val >= bucket_keys[i] && i < length(bucket_keys)) i+=1; end
        if haskey(buckets, bucket_keys[i]) push!(buckets[bucket_keys[i]], val)
        else buckets[bucket_keys[i]] = [val]; end
    end
    for key in sort(collect(keys(buckets)))
        buckets[key] = sort(buckets[key])
        append!(out, buckets[key])
    end
    return out
end

function bucket_sort(input::Vector{Int64}, r::Int64)::Vector{Int64} # O(m+r)
    count = zeros(Int64, r)
    out = zeros(Int64, length(input))

    @simd for val in input # O(m)
        count[val+1] += 1 # simd allows multiple additions to be processed simultaneously
    end

    point = 1
    @inbounds for i in 1:r # O(r)
        next_point = point + Int(count[i])
        if next_point > length(input) + 1 return out; end
        out[point:next_point-1] .= i-1
        point = next_point
    end

    return out
end
