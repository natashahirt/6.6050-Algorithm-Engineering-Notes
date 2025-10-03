using Graphs
using GraphMakie
using GLMakie
using Random
using Metis

include("get_separator_bu.jl")
include("get_separator_metis.jl")

# Generate a small-world graph (resembles social networks)
Random.seed!(42)
num_vertices = 200
avg_degree = 6           # each node connects to k nearest neighbors in ring
rewire_prob = 0.05       # small rewiring -> high clustering + short paths
g_ws = watts_strogatz(num_vertices, avg_degree, rewire_prob; is_directed=false)

m = 3  # edges each new node adds
g_ba = barabasi_albert(num_vertices, m; is_directed=false)

# Plot the graph
f = Figure(resolution = (800, 400))
ax1 = Axis(f[1, 1], title = "Watts-Strogatz Graph")
ax2 = Axis(f[1, 2], title = "Barabási-Albert Graph")

# Draw both graphs
graphplot!(ax1, g_ws, 
    node_size = 10,
    edge_width = 1,
    layout = GraphMakie.Spring(dim=2))
graphplot!(ax2, g_ba,
    node_size = 10, 
    edge_width = 1,
    layout = GraphMakie.Spring(dim=2))

display(f)


# Test separator functions
# Bottom-up
sep_tree_bu = bu_separator_tree(g_ws)
sep_tree_metis = metis_separator_tree(g_ws)

plot_separator_tree(sep_tree_bu)
plot_separator_tree(sep_tree_metis)