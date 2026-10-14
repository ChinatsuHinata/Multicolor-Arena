"""Deterministic Swiss matching with no rematches and no repeated allocated bye."""
from collections import deque


def perfect_matching(graph):
    """Edmonds' alternating-path/blossom algorithm for a general graph."""
    n = len(graph)
    matched = [-1] * n
    for root in range(n):
        if matched[root] != -1:
            continue
        parent = [-1] * n
        base = list(range(n))
        used = [False] * n
        queue = deque([root])
        used[root] = True

        def common_base(a, b):
            ancestors = set()
            while True:
                a = base[a]
                ancestors.add(a)
                if matched[a] == -1:
                    break
                a = parent[matched[a]]
            while base[b] not in ancestors:
                b = parent[matched[base[b]]]
            return base[b]

        def mark_path(vertex, ancestor, child, blossom):
            while base[vertex] != ancestor:
                blossom[base[vertex]] = blossom[base[matched[vertex]]] = True
                parent[vertex] = child
                child = matched[vertex]
                vertex = parent[matched[vertex]]

        endpoint = -1
        while queue and endpoint == -1:
            vertex = queue.popleft()
            for other in graph[vertex]:
                if base[vertex] == base[other] or matched[vertex] == other:
                    continue
                if other == root or matched[other] != -1 and parent[matched[other]] != -1:
                    ancestor = common_base(vertex, other)
                    blossom = [False] * n
                    mark_path(vertex, ancestor, other, blossom)
                    mark_path(other, ancestor, vertex, blossom)
                    for index in range(n):
                        if blossom[base[index]]:
                            base[index] = ancestor
                            if not used[index]:
                                used[index] = True
                                queue.append(index)
                elif parent[other] == -1:
                    parent[other] = vertex
                    if matched[other] == -1:
                        endpoint = other
                        break
                    used[matched[other]] = True
                    queue.append(matched[other])
        if endpoint != -1:
            while endpoint != -1:
                previous = parent[endpoint]
                following = matched[previous]
                matched[endpoint], matched[previous] = previous, endpoint
                endpoint = following
    if any(value == -1 for value in matched):
        return None
    return [(a, b) for a, b in enumerate(matched) if a < b]


def swiss_pairs(standings, previous_pairs, previous_byes):
    """Minimize the largest score gap, then prefer nearby ranks in edge order."""
    ranks = {entry["player_id"]: index for index, entry in enumerate(standings)}
    blocked = {frozenset(pair) for pair in previous_pairs}
    byes = [None] if len(standings) % 2 == 0 else [entry["player_id"] for entry in reversed(standings)
                                                   if entry["player_id"] not in previous_byes]
    for bye in byes:
        players = [entry for entry in standings if entry["player_id"] != bye]
        gaps = sorted({abs(a["points"] - b["points"]) for a in players for b in players})
        for maximum_gap in gaps:
            graph = []
            for a in players:
                neighbors = [index for index, b in enumerate(players) if b != a
                             and frozenset((a["player_id"], b["player_id"])) not in blocked
                             and abs(a["points"] - b["points"]) <= maximum_gap]
                neighbors.sort(key=lambda index: (abs(a["points"] - players[index]["points"]),
                               abs(ranks[a["player_id"]] - ranks[players[index]["player_id"]]), players[index]["seed"]))
                graph.append(neighbors)
            matching = perfect_matching(graph)
            if matching is not None:
                result = [(players[a]["player_id"], players[b]["player_id"]) for a, b in matching]
                if bye is not None:
                    result.append((bye, None))
                return result
    raise ValueError("无法在不重复对手或轮空的条件下编排下一轮，请主办方检查轮数")
