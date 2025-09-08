using Graphs, GLMakie, GraphMakie
using GraphMakie.NetworkLayout
using Random

include("bfs.jl")

function kary_tree_digraph(k::Int, levels::Int)
    n = (k^(levels + 1) - 1) ÷ (k - 1)
    g = SimpleDiGraph(n)
    for v in 1:((n - 1) ÷ k)          # internal nodes only
        for i in 1:k
            child = k*(v - 1) + i + 1
            add_edge!(g, v, child)
        end
    end
    return g
end

g = kary_tree_digraph(4, 3)

g = kronecker(4, 16, 0.57, 0.19, 0.19, rng=Random.MersenneTwister(42))
g = kronecker(5, 32, 0.57, 0.19, 0.19, rng=Random.MersenneTwister(42)) # Creates a Kronecker graph with 2^5=32 initial vertices, iterated 32 times

f, ax, p = graphplot(g, 
    node_color = fill(:black, nv(g)),
    edge_color = fill(:black, ne(g))
)
display(f)

parents = bfs(g, method=:bottomup)

f, ax = animate_bfs(g, method=:bottomup, dt=0.1, hybrid=false, parallel=false, savepath = "./bfs/animations/serial/bfs_bu_tree_lowres.gif")

GC.gc()
