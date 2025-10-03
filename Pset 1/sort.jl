using Random
include("utils.jl")

n = 20 # number of values in the array
r = 5 # number of unique integers (n % r = 0)
n_rows = div(n, r)

# step 0: generate A
A = rand(0:(r-1), n)

Bs = [A[(i-1) * r + 1 : i * r] for i in 1:Int(n/r)]
B_sorted = [bucket_sort(b, r) for b in Bs] # is stable within each individual subarray
B = vcat(B_sorted...)

# count the number of elements whose value is v (histogram)
# for each individual vector run a parallel thread
number = zeros(Int, n_rows, r)
Threads.@threads for s in 1:n_rows # slowdowns for these small arrays but just to make my point
    # O(m) work because we're iterating over each value in the array
    # O(r) span because each B is only r long
    @simd for v in B_sorted[s] 
        number[s, v+1] += 1 # simd allows multiple additions to be processed simultaneously
    end
end
number

function get_number(s, v)
    i_start = (s-1) * r + 1
    i_end = s * r
    count = 0
    @inbounds while i_start <= i_end && B[i_start] <= v
        count += (B[i_start] == v)
        i_start += 1
    end
    return count
end

function get_number(i)
    s = ceil(Int, i/r) # s = row number
    v = B[i]
    return get_number(s, v)
end

# get the row-rank of each item
serial = zeros(Int64, n)
Threads.@threads for s in 1:n_rows # slowdowns for these small arrays but just to make my point
    # O(m) work because looking at each value once and at most one operation per value
    # O(r) span because need to do each row independently
    serial[(s-1)*r + 1] = 0
    n_value = 0
    for t in 2:r # 1 is starting index and will be 0 regardless
        if B_sorted[s][t] == B_sorted[s][t-1]
            n_value += 1
        else
            n_value = 0 # first value of the kind
        end 
        serial[(s-1)*r + t] = n_value # how many values of the same kind have come before?
    end
end
serial

function get_serial(i)
    col = ((i-1)%r) + 1
    s = ceil(Int, i/r) # s = row number
    v = B[i]
    sub_rank = 0
    for j in 1:col-1
        if B[((s-1) * r) + j] == v
            sub_rank += 1
        end
    end
    return sub_rank
end


function get_serial(i)
    col = ((i-1)%r) + 1
    s = ceil(Int, i/r) # s = row number
    v = B[i]
    sub_rank = 0
    for j in 1:col-1
        if B[((s-1) * r) + j] == v
            sub_rank += 1
        end
    end
    return sub_rank
end


sum(number[:,1])

function rank(i)
    col = B[i] + 1 # julia's one-indexing
    row = ceil(Int, i/r)
    rank = (col > 1 ? sum([sum(number[:, v]) for v in 1:col-1]) : 0) + 
                sum(number[1:row-1,col]) + get_serial(i) # or serial[i]
                + 1
    return rank
end

Set(rank(i) for i in 1:n)

"""
it is a stable sorting algorithm -- because we keep track of the number of elements
less than the value we are looking to sort that have preceded it and the number of elements
equal to the value we are sorting that have preceded it in the original input order, the 
second 3 in A is also going to be the second 3 in output B

the basic algorithm requires two additional things: an r x (n/r) vector of vectors (or matrix, 
in this implementation) and an n vector (serial) denoting the number of preceding equal
elements in each subvector

the algorithm is not in-place because we are not overwriting the original A array. we could
sort the A array in-place and call the numbers function individually and then it would be an 
O(1) extra storage algorithm as we'd only be storing a few helper variables. the massive
tradeoff is that every time we'd want to calculate the number of smaller values we wouldn't
have a pre-calculated matrix to index into but would need to go through all O(n) values with
every rank calculation in the worst case.

the trick is probably that we'd need to select a base (for the radix sort) that is equal to
k. That means that we'd need to, at most, count each of the n digits k times. 
"""