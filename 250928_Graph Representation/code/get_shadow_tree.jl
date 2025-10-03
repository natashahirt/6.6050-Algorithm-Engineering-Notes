using Graphs

struct ShadowNode

    root::Int64
    labels::Vector{Int64}
    children::Vector{ShadowNode}

    function ShadowNode(root::Int64, labels::Vector{Int64}=Int64[], children::Vector{ShadowNode}=ShadowNode[])
        return new(root, labels, children)
    end

    function ShadowNode(root::MetisTreeNode)

    end

end

function get_shadow_tree(id::Int64)

    

end