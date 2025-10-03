using Graphs, GLMakie, GraphMakie
using GraphMakie.NetworkLayout

outnbrs(g, v) = is_directed(g) ? outneighbors(g, v) : neighbors(g, v)
innbrs(g, v)  = is_directed(g) ? inneighbors(g, v)  : neighbors(g, v)

# standard bfs algorithm
function bfs(g::AbstractGraph; s::Integer=1, method::Symbol=:topdown)
    if !(method in [:topdown, :bottomup])
        throw(ArgumentError("method must be either :topdown or :bottomup"))
    end

    parents = fill(-1, nv(g))
    parents[s] = 0
    frontier = [Int(s)]

    while !isempty(frontier)
        if method == :topdown
            frontier = top_down_step!(g, frontier, parents)
        elseif method == :bottomup
            frontier = bottom_up_step!(g, frontier, parents)
        end
    end

    return parents
end

function top_down_step!(g::AbstractGraph, frontier::Vector{Int}, parents::Vector{Int})
    next_frontier = Int[]
    for v in frontier
        for n in outnbrs(g, v)
            if parents[n] == -1 # check if already seen
                parents[n] = v
                push!(next_frontier, n)
            end
        end
    end
    return next_frontier
end

function bottom_up_step!(g::AbstractGraph, frontier::Vector{Int}, parents::Vector{Int})
    frontier = Set(frontier)
    next_frontier = Int[]
    
    for v in vertices(g)
        if parents[v] == -1 # undiscovered
            for n in innbrs(g, v)
                if n in frontier
                    parents[v] = n
                    push!(next_frontier, v)
                    break
                end
            end
        end
    end
    
    return next_frontier
end

function animate_bfs(g::AbstractGraph; s::Int=1, method::Symbol=:topdown, dt::Float64=0.1, layout=Spring(), 
                     savepath::Union{Nothing,AbstractString}=nothing, framerate::Union{Nothing,Int}=nothing,
                     parallel::Bool=false, hybrid::Bool=false, alpha::Int=14, beta::Int=24)

    """
    default alpha value = 14
    default beta value = 24
    """

    if !(method in [:topdown, :bottomup])
        throw(ArgumentError("method must be either :topdown or :bottomup"))
    end

    if hybrid && method == :bottomup
        method = :topdown # for first step
    end

    deg(v) = length(method == :bottomup ? innbrs(g, v) : outnbrs(g, v))

    # set up graph
    node_colors = Observable(fill(:black, nv(g)))
    current_node_colors =fill(:black, nv(g))
    edge_colors = Observable(fill(:black, ne(g)))
    edge_widths = Observable(fill(0.2, ne(g)))
    claimed_positions = Observable(fill((0,0),4))
    failed_positions = Observable(fill((0,0),4))
    peer_positions = Observable(fill((0,0),4))
    valid_parent_positions = Observable(fill((0,0),4))
    method_obs = Observable(method)  # :topdown or :bottomup
    nf = Observable(0)
    mf = Observable(0)
    mu = Observable(0)
    current_level = Observable(0)

    # set up figure
    f = Figure(size=(1400, 800))
    ax_graph = Axis(f[1,1], title="Graph")
    ax_bar = Axis(f[1,2], title="Neighbor Types", xlabel="Level", ylabel="Count", xgridvisible=false, ygridvisible=false)
    ylims!(ax_bar, 0, nothing)
    
    graphplot!(ax_graph, g; node_color=node_colors, edge_color=edge_colors, layout=layout, edge_width=edge_widths, arrow_size=5)
    
    scatterlines!(ax_bar, claimed_positions, color=:gold, label="Claimed")
    scatterlines!(ax_bar, failed_positions, color=:orange, label="Failed")
    scatterlines!(ax_bar, peer_positions, color=:lightblue, label="Peer")
    scatterlines!(ax_bar, valid_parent_positions, color=:darkblue, label="Valid parent")

    Legend(f[2,:], ax_bar, framevisible=false, orientation=:horizontal)
    Label(f[2, :], lift((meth, cl,n,m,u) -> "$meth\ncurrent level=$cl    nf=$n   mf=$m   mu=$u", method_obs, current_level, nf, mf, mu), fontsize=16, halign=:left, justification=:left)

    hidedecorations!(ax_graph); hidespines!(ax_graph)
    hidespines!(ax_bar, :t, :r)
    display(f)

    # get edge map
    edge_is = Dict{Tuple{Int,Int},Int}()
    for (idx, edge) in enumerate(collect(edges(g)))
        u, v = src(edge), dst(edge)
        edge_is[(u, v)] = idx
        edge_is[(v, u)] = idx
    end

    # set up bfs
    parents = fill(-1, nv(g))
    parents[s] = 0 # loop back to self
    node_colors[][s] = :red; notify(node_colors)
    current_node_colors[s] = :gold
    
    depths = fill(0, nv(g))
    frontier = [Int(s)]
    nf[] = length(frontier) # number of values in the frontier
    mf[] = sum(length(outnbrs(g, n)) for n in frontier) # number of edges leading away from frontier
    mu[] = sum(deg(v) for v in 1:nv(g) if v != s) # number of unexplored edges
    notify(current_level); notify(nf); notify(mf); notify(mu)
    println("method = $(method)\ncurrent level = $(current_level[]) nf = $(nf[]), mf = $(mf[]), mu = $(mu[])")

    function run!(step!)
        step!() # capture state

        while !isempty(frontier)

            frontier = Set(frontier)
            next_frontier = Int[]
            current_level[] += 1

            if hybrid
                if mf[] > mu[] / alpha # = C_TB, frontier is large so switch to bottom-up
                    method = :bottomup
                    method_obs[] = method
                elseif nf[] < nv(g) / beta # = C_BT, frontier is small again
                    method = :topdown
                    method_obs[] = method
                end
                println("method = $method")
                notify(method_obs);
            end

            push!(claimed_positions.val, (current_level[], 0))
            push!(failed_positions.val, (current_level[], 0))
            push!(peer_positions.val, (current_level[], 0))
            push!(valid_parent_positions.val, (current_level[], 0))
            notify(claimed_positions); notify(failed_positions); notify(peer_positions); notify(valid_parent_positions)
            autolimits!(ax_bar)
            step!()

            if method == :topdown

                if parallel; sleep(dt); end
                
                for v in frontier

                    node_colors[][v] = :red; notify(node_colors)
                    if !parallel; step!(); end
                    ns = outnbrs(g, v)
                    neighbor_edges = [edge_is[(v, n)] for n in ns]

                    for edge in neighbor_edges
                        edge_colors[][edge] = :pink
                        edge_widths[][edge] = 2
                    end

                    notify(edge_colors); notify(edge_widths)

                    #if parallel; sleep(dt); end # wait a second so that it's a little less speedy

                    for (edge_i, n) in zip(neighbor_edges, ns)

                        edge_colors[][edge_i] = :red; notify(edge_colors) #; step!()

                        if parents[n] == -1 # the new node is unclaimed/has no parent yet: claimed child
                            
                            parents[n] = v
                            node_colors[][n] = :gold; notify(node_colors)
                            edge_colors[][edge_i] = :gold; notify(edge_colors)
                            claimed_positions[][end] = (current_level[], claimed_positions[][end][2]+1); notify(claimed_positions); autolimits!(ax_bar)
                            depths[n] = depths[v] + 1
                            if !isempty(outnbrs(g,n))
                                current_node_colors[n] = node_colors[][n]
                                node_colors[][n] = :pink; notify(node_colors)
                                push!(next_frontier, n)
                            end
                            if !parallel; step!(); end

                        elseif depths[n] == depths[v] # peer
                            
                            node_colors[][n] = :lightblue; notify(node_colors)
                            edge_colors[][edge_i] = :lightblue; notify(edge_colors)
                            peer_positions[][end] = (current_level[], peer_positions[][end][2]+1); notify(peer_positions); autolimits!(ax_bar)
                            if !parallel; step!(); end

                        elseif depths[n] == depths[v] - 1 # valid parent
                            
                            node_colors[][n] = :darkblue; notify(node_colors)
                            edge_colors[][edge_i] = :darkblue; notify(edge_colors)
                            valid_parent_positions[][end] = (current_level[], valid_parent_positions[][end][2]+1); notify(valid_parent_positions); autolimits!(ax_bar)
                            if !parallel; step!(); end

                        else # failed child

                            node_colors[][n] = :orange; notify(node_colors)
                            edge_colors[][edge_i] = :orange; notify(edge_colors)
                            failed_positions[][end] = (current_level[], failed_positions[][end][2]+1); notify(failed_positions); autolimits!(ax_bar)
                            if !parallel; step!(); end
                        
                        end

                    end

                    node_colors[][v] = current_node_colors[v]; notify(node_colors)
                    if !parallel; step!(); end
         
                end
 
            elseif method == :bottomup

                for v in frontier
                    current_node_colors[v] = node_colors[][v]
                end
                step!()
                
                for v in vertices(g)

                    if parents[v] == -1 # undiscovered

                        node_colors[][v] = :red; notify(node_colors)
                        
                        ns = innbrs(g, v)
                        edges = [edge_is[(n,v)] for n in ns]

                        for edge in edges
                            edge_colors[][edge] = :pink; notify(edge_colors)
                            edge_widths[][edge] = 2; notify(edge_widths)
                        end

                        if !parallel; step!(); end

                        found_parent = false

                        for (n, edge) in zip(ns, edges)

                            edge_colors[][edge] = :red; notify(edge_colors)
                            if !parallel; step!(); end

                            if n in frontier

                                parents[v] = n
                                depths[v] = current_level[] + 1
                                node_colors[][v] = :gold; notify(node_colors)
                                if !parallel; step!(); end
                                
                                if any(u -> parents[u] == -1, outnbrs(g, v))  # only helpful if v can discover someone next
                                    push!(next_frontier, v)
                                end

                                edge_colors[][edge] = :gold; notify(edge_colors)
                                found_parent = true
                                claimed_positions[][end] = (current_level[], claimed_positions[][end][2]+1); notify(claimed_positions); autolimits!(ax_bar)
                                break

                            elseif parents[n] != -1 && depths[n] == current_level[] 
                                
                                edge_colors[][edge] = :lightblue; notify(edge_colors)
                                peer_positions[][end] = (current_level[], peer_positions[][end][2]+1); notify(peer_positions); autolimits!(ax_bar)
                                if !parallel; step!(); end

                            else

                                edge_colors[][edge] = :orange; notify(edge_colors)
                                failed_positions[][end] = (current_level[], failed_positions[][end][2]+1); notify(failed_positions); autolimits!(ax_bar)
                                if !parallel; step!(); end

                            end

                        end

                        if !found_parent
                            for e in edges
                                edge_colors[][e] = :lightgray; notify(edge_colors)
                                edge_widths[][e] = 0.2; notify(edge_widths)
                            end
                            node_colors[][v] = :lightgray; notify(node_colors)
                        end

                        if !parallel; step!(); end

                    end

                end
                
                for v in frontier
                    node_colors[][v] = :gold; notify(node_colors)
                end
                for v in next_frontier
                    node_colors[][v] = :red; notify(node_colors)
                end

                step!()
                
            end

            frontier = Set(next_frontier)
            nf[] = length(frontier) # update number of values in the frontier
            mf[] = isempty(frontier) ? 0 : sum(length(outnbrs(g, n)) for n in frontier) # number of edges leading away from frontier
            mu[] = isempty(frontier) ? 0 : mu[] - sum(deg(v) for v in frontier)

            notify(current_level); notify(nf); notify(mf); notify(mu)
            println("current level = $(current_level[]) nf = $(nf[]), mf = $(mf[]), mu = $(mu[])")

        end
    end
    
    if savepath === nothing
        run!(()->sleep(dt))
    else
        fps = isnothing(framerate) ? max(1, round(Int, 1/dt)) : framerate
        record(f, savepath; framerate=fps, resolution=(700,400)) do io
            run!(()->recordframe!(io))
        end
    end

    return (parents = parents, fig = f)
end

function kary_tree_digraph(k::Int, levels::Int)
    n = (k^(levels + 1) - 1) ÷ (k - 1)
    g = SimpleDiGraph(n)
    for v in 1:((n - 1) ÷ k)          # internal nodes only
        for i in 1:k
            child = k*(v - 1) + i + 1
            add_edge!(g, v, child)
        end
    end
end

