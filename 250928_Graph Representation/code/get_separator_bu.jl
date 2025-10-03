using Graphs
using Base.Threads: Atomic, atomic_add!, atomic_xchg!
using DataStructures
using Random

const BALANCE_WEIGHT = 0.01
const NEXT_NODE_ID = Atomic{Int}(0)
next_node_id() = atomic_add!(NEXT_NODE_ID, 1) + 1

mutable struct SuperNode
    id::Int64
    n_vertices::Int64 # n original vertices in the supernode
    vertex_ids::Set{Int64}
    neighbors::Dict{Int64, Int64} # n edges connecting the supernode to other supernodes
    n_updates::Int64 # how many updates has this supernode gone through?
    parent::Union{SuperNode, Nothing} # have we deleted this supernode?

    function SuperNode(n_vertices::Int64=1, vertex_ids::Set{Int64}=Set{Int64}(), neighbors::Dict{Int64, Int64}=Dict{Int64, Int64}(), n_updates::Int64=0, parent::Union{SuperNode, Nothing}=nothing)
        id = next_node_id()
        init_vertex_ids = Set{Int64}([id])
        supernode = new(id, n_vertices, init_vertex_ids, neighbors, n_updates, parent)
        return supernode
    end
end

mutable struct MergeTreeNode
    id::Int64
    supernode::SuperNode
    left::Union{MergeTreeNode, Nothing}
    right::Union{MergeTreeNode, Nothing}

    function MergeTreeNode(supernode::SuperNode, left::Union{MergeTreeNode, Nothing}=nothing, right::Union{MergeTreeNode, Nothing}=nothing)
        id = supernode.id
        new(id, supernode, left, right)
    end
end

function initialize(g::AbstractGraph)
    atomic_xchg!(NEXT_NODE_ID, 0)
    supernodes = Dict{Int64, SuperNode}()
    mergetreenodes = Dict{Int64, MergeTreeNode}()

    for i in 1:nv(g)
        supernode = SuperNode()
        supernodes[supernode.id] = supernode
        mergetreenodes[supernode.id] = MergeTreeNode(supernode)
    end

    for (i, v) in enumerate(vertices(g))
        supernode = supernodes[i]
        for ngbr in outneighbors(g, v)
            if ngbr != i
                ngbr_node = supernodes[ngbr]
                if haskey(supernode.neighbors, ngbr_node.id)
                    supernode.neighbors[ngbr_node.id] += 1
                else
                    supernode.neighbors[ngbr_node.id] = 1
                end
            end
        end
    end

    return supernodes, mergetreenodes
end

function update_neighbor!(node::SuperNode, old::Int64, C::Int64)
    d = node.neighbors
    haskey(d, old) || return(node) # check if it exists (should always exist)
    v = pop!(d, old)
    if haskey(d, C)
        d[C] += v
    else
        d[C] = v
    end
    node.n_updates += 1
    return node
end

function node_merge(idx_A::Int64, idx_B::Int64, supernodes::Dict{Int64, SuperNode}, mergetreenodes::Dict{Int64, MergeTreeNode})
    A = supernodes[idx_A]
    B = supernodes[idx_B]

    @assert A.parent == nothing && B.parent == nothing "Cannot merge nodes that have already been merged into other supernodes" # otherwise fail

    C = SuperNode(A.n_vertices + B.n_vertices, union(A.vertex_ids, B.vertex_ids),
                  merge((x,y) -> x + y, A.neighbors, B.neighbors))

    delete!(C.neighbors, A.id)
    delete!(C.neighbors, B.id)

    supernodes[C.id] = C
    mergetreenodes[C.id] = MergeTreeNode(C, mergetreenodes[A.id], mergetreenodes[B.id])

    for (ngbr_id, n_edges) in A.neighbors
        update_neighbor!(supernodes[ngbr_id], A.id, C.id)
    end

    for (ngbr_id, n_edges) in B.neighbors
        update_neighbor!(supernodes[ngbr_id], B.id, C.id)
    end

    # clean up
    A.parent = C
    B.parent = C

    return C, supernodes, mergetreenodes
end

function score(A::SuperNode, B::SuperNode)
    wAB = float(get(A.neighbors, B.id, 0))
    sA = float(A.n_vertices)
    sB = float(B.n_vertices)
    total = sA + sB
    total == 0 && return 0.0

    strength = wAB / total
    imbalance = abs(sA - sB) / total

    return strength - BALANCE_WEIGHT * imbalance
end


function find_separator(supernodes::Dict{Int64, SuperNode}, mergetreenodes::Dict{Int64, MergeTreeNode})
    pq = PriorityQueue{Tuple{Int,Int,Int,Int},Tuple{Float64,Float64}}()
    root_id = nothing

    # initialize all the leaves on the priority queue
    seen = Set{Tuple{Int,Int}}()
    for a in keys(supernodes)
        isnothing(supernodes[a].parent) || continue
        for (b, n_edges_AB) in supernodes[a].neighbors
            haskey(supernodes, b) || continue
            isnothing(supernodes[b].parent) || continue
            aa, bb = (a <= b) ? (a, b) : (b, a)
            if aa != bb && !((aa, bb) in seen)
                push!(seen, (aa, bb))
                new_score = score(supernodes[aa], supernodes[bb])
                enqueue!(pq, (aa, bb, supernodes[aa].n_updates, supernodes[bb].n_updates) => (-new_score, rand()))
            end
        end
    end

    while !isempty(pq)
        (a, b, ver_a, ver_b), _ = peek(pq)
        dequeue!(pq)
        if supernodes[a].n_updates != ver_a || 
           supernodes[b].n_updates != ver_b ||
           !isnothing(supernodes[a].parent) || 
           !isnothing(supernodes[b].parent); # stale
           continue 
        end

        C, supernodes, mergetreenodes = node_merge(a, b, supernodes, mergetreenodes)
        root_id = C.id

        for (nb, _) in C.neighbors
            haskey(supernodes, nb) || continue
            isnothing(supernodes[nb].parent) || continue
            aa, bb = (C.id <= nb) ? (C.id, nb) : (nb, C.id)
            if aa != bb
                new_score = score(supernodes[aa], supernodes[bb])
                enqueue!(pq, (aa, bb, supernodes[aa].n_updates, supernodes[bb].n_updates) => (-new_score, rand()))
            end
        end

    end

    return supernodes, mergetreenodes, root_id

end

function bu_separator_tree(g)
    s, m = initialize(g);
    s1, m1, root_id = find_separator(s, m);
    
    r_map = Dict{Int64, Int64}()
    for i in 1:root_id
        r_map[i] = root_id - i + 1
    end
    separator_g = SimpleDiGraph(length(keys(m1)))
    queue = [root_id]
    while !isempty(queue)
        curr = popfirst!(queue)
        root = m1[curr]
        if !isnothing(root.left)
            add_edge!(separator_g, r_map[curr], r_map[root.left.id])
            push!(queue, root.left.id)
        end
        if !isnothing(root.right)
            add_edge!(separator_g, r_map[curr], r_map[root.right.id])
            push!(queue, root.right.id)
        end
    end

    return separator_g
end

function plot_separator_tree(g::AbstractGraph)
    f = Figure()
    ax = Axis(f[1,1])
    graphplot!(ax, g, layout=GraphMakie.Buchheim())
    display(f)
end