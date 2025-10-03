using Graphs
using Metis


struct MetisTreeNode

    V::Vector{Int64} # subtree
    S::Vector{Int64} # separators
    left::Union{Nothing, MetisTreeNode}
    right::Union{Nothing, MetisTreeNode}

    function MetisTreeNode(V, S, left=nothing, right=nothing)
        new(V, S, left, right)
    end

end

function partition_metis(g::AbstractGraph, V::Vector{Int64})
    sub_g, map = induced_subgraph(g, V)
    partition = Metis.separator(sub_g)
    left = map[findall(==(1), partition)]
    sep = map[findall(==(3), partition)]
    right = map[findall(==(2), partition)]
    return left, sep, right
end

function metis_separator_tree(g::AbstractGraph, V::Vector{Int})
    left, sep, right = partition_metis(g, V)
    if isempty(left) || isempty(sep) || isempty(right)
        return MetisTreeNode(V, Int[], nothing, nothing)
    end
    # left
    new_left = metis_separator_tree(g, left)
    new_right = metis_separator_tree(g, right)
    return MetisTreeNode(V, sep, new_left, new_right)
end

function metis_separator_tree(g::AbstractGraph)
    return metis_separator_tree(g, collect(vertices(g)))
end

function plot_separator_tree(root::MetisTreeNode; show_labels::Bool=true)
    # 1) Assign compact ids to tree nodes
    idmap = IdDict{MetisTreeNode,Int}()
    order = MetisTreeNode[]
    stack = MetisTreeNode[root]
    while !isempty(stack)
        n = pop!(stack)
        if !haskey(idmap, n)
            idmap[n] = length(idmap) + 1
            push!(order, n)
            if n.left  !== nothing; push!(stack, n.left);  end
            if n.right !== nothing; push!(stack, n.right); end
        end
    end

    # 2) Build directed graph parent -> child
    g = SimpleDiGraph(length(idmap))
    for (n, i) in idmap
        if n.left  !== nothing; add_edge!(g, i, idmap[n.left]);  end
        if n.right !== nothing; add_edge!(g, i, idmap[n.right]); end
    end

    f = Figure()
    ax = Axis(f[1,1])
    graphplot!(ax, g; layout = GraphMakie.Buchheim())
    display(f)
end
