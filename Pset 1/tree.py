import math

class Link:
    
    def __init__(self, val=-1, parent=None, next_euler=None):
        self.val = val


n_nodes = 6
parents = [0,0,0,1,3,3]
euler_tour = [0,1,3,4,3,5,3,1,0,2,0]

links = [Link(i) for i in range(n_nodes)]

for (i,link) in enumerate(links):
    link.parent = links[parents[i]]

# algorithm
def dfs_order(links, euler_tour):
    filter_list = [False for _ in range(len(euler_tour))]
    filter_list[0] = True

    for i in range(len(euler_tour)-1): # do parallel
        link = links[euler_tour[i]]
        if link.parent.val != euler_tour[i+1]:
            filter_list[i+1] = True
    
    pref_sums = [0 for _ in range(len(euler_tour))]

    for i in range(len(euler_tour)-1):  # do parallel (filter)
        if filter_list[i]:
            pref_sums[i+1] = pref_sums[i] + 1
        else:
            pref_sums[i+1] = pref_sums[i]

    # same as filter processing but reversing the assignment to get D
    D = [0 for _ in range(pref_sums[-1])]
    A = [0 for _ in range(pref_sums[-1])]
    for i in range(len(euler_tour)-1):
        if pref_sums[i] != pref_sums[i+1]:
            A[pref_sums[i]] = euler_tour[i]
            D[euler_tour[i]] = pref_sums[i]

dfs_order(links, euler_tour)

def get_rank(links):
    rank = [1 for _ in range(n_nodes)]
    rank[0] = 0
    temp_rank = [0 for _ in range(n_nodes)]
    temp_parent = [Link() for _ in range(n_nodes)]
    for j in range(math.ceil(math.log(n_nodes, 2))-1):
        for i in range(n_nodes):
            temp_rank[i] = rank[links[i].parent.val]
            temp_parent[i] = links[i].parent.parent
        for i in range(n_nodes):
            rank[i] = rank[i] + temp_rank[i]
            links[i].parent = temp_parent[i]
        print(rank)

get_rank(links)