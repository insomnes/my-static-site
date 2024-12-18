# Day 18. Ram run
- [AoC day page](https://adventofcode.com/2024/day/18)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/18_ramrun)

We are inside a computer now! User wrote strange program, so now bytes are falling on
the RAM block we are standing on. We need to avoid them and reach the end of the block.

## Part One
In the first part we just need to find the shortest path from the start to the end
when only the first kilobyte (1024) has fallen. Each fallen byte is a wall on the grid.
Start is at `(0, 0)` and end is at `(70, 70)`.

First we need to parse the input and prepare [the grid](https://github.com/insomnes/aoc/blob/main/2024/18_ramrun/solution/grid.go), setting cells blocked by fallen bytes:


```go
type FallingBytes []Point[rune]

type ParsedInput = FallingBytes
...


func prepareStartGrid(fallingBytes FallingBytes, size int, timeFrame int) *Grid[rune] {
	grid := NewGridWithDefault(size, size, EmptyChar)
	for _, p := range fallingBytes[:timeFrame] {
		grid.Set(p.Row, p.Col, p.Value)
	}
	return grid
}

```

With the shortest path search we can implement 
[Dijkstra's algorithm](https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm) 
or [A* (a-star) algorithm](https://en.wikipedia.org/wiki/A*_search_algorithm) which is 
an optimization for the former.

To have them go we would need [the priority queue (or a heap)](https://github.com/insomnes/aoc/blob/main/2024/18_ramrun/solution/heap.go).

We don't need full routing table for the path, so we can just work with distances, you
can think of it as DFS with a priority queue instead of a stack:

```go
func FindShortestPath(g *Grid[rune], less func(a, b Step) bool) int {
	unknownStep := Step{Row: -1, Col: -1, StpCnt: -1, Metric: -1}
	visited := NewGridWithDefault(g.Rows, g.Columns, unknownStep)
	endRow, endCol := g.Rows-1, g.Columns-1

	startStep := NewStartStep(g)
	queue := NewHeap[Step](less, 200)
	queue.Push(startStep)

	for queue.Len() > 0 {
		step := queue.Pop()
        // Finish condition
		if step.Row == endRow && step.Col == endCol {
			visited.Set(step.Row, step.Col, step)
			break
		}

        // Do not visit already visited steps, by design we've reach each point
        // with the shortest path
		knownStep := visited.Get(step.Row, step.Col).Value
		if knownStep.StpCnt != -1 {
			continue
		}
 
        // Mark step as visited, and find next steps
		visited.Set(step.Row, step.Col, step)
		nextSteps := findNextSteps(g, step, visited)

        // Update queue
		for _, nextStep := range nextSteps {
			queue.Push(nextStep)
		}
	}

    // In the end we have the shortest path set to the end point.
    // -1 means that the path is not found
	return visited.Get(endRow, endCol).Value.StpCnt
}
```

Steps prioritazation logic is based on the steps count from the start point. With
A* we also add heuristic metric to the steps count. 
I've used Manhattan distance to the end point, cause it's fine for the grid without
diagonal movement:

```go
type Step struct {
	Row, Col int
	StpCnt   int
	Metric   int
}

func NewStartStep(g *Grid[rune]) Step {
	return Step{
		Row:    0,
		Col:    0,
		StpCnt: 0,
		Metric: manhattanToEnd(0, 0, g),
	}
}

// Specific less functions for the priority queue to choose
// the next step to visit. Used function determines the algorithm.
func lessForDijkstra(a, b Step) bool {
	return a.StpCnt < b.StpCnt
}

func lessForAStar(a, b Step) bool {
	return a.StpCnt+a.Metric < b.StpCnt+b.Metric
}
```

Next steps logic is simple using grid and we just need to properly set new step metric.
We also can skip already visited steps here:

```go
func findNextSteps(g *Grid[rune], step Step, visited *Grid[Step]) []Step {
	steps := make([]Step, 0, 4)
	for _, neighbor := range g.GetNeighborsCross(step.Row, step.Col) {
		if neighbor.Value == ByteChar {
			continue
		}
		if visited.Get(neighbor.Row, neighbor.Col).Value.StpCnt != -1 {
			continue
		}
		row, col, sCount := neighbor.Row, neighbor.Col, step.StpCnt+1
        // Without diagonal movement we can use Manhattan distance as A* heuristic
		metric := manhattanToEnd(row, col, g)
		newStep := Step{Row: row, Col: col, StpCnt: sCount, Metric: metric}
		steps = append(steps, newStep)

	}
	return steps
}
```

Answer is the shortest path step count:
```go
const (
	TestGridSize  = 7
	TestTimeFrame = 12
	GridSize      = 71
	TimeFrame     = 1024
)
...

func PartOne(inp ParsedInput) int {
	size, tf := GridSize, TimeFrame

	grid := prepareStartGrid(inp, size, tf)

    // We use A* algorithm to find the shortest path, you can switch to Dijkstra
    // by changing the less function
	return FindShortestPath(grid, lessForAStar)
}
```

## Part Two
In part two we want to know at which time and space point (of falling byte) our
path would be fully blocked. We need to find the time frame when the path is blocked.


### Naive approach
We can do it by adding the falling bytes after initial ones and check if the path
is blocked at each time frame:

```go
// We can skip bytes until the time frame, cause we know they are not blocking anything
// from part one. Also grid already contains them, so we don't need to set them again.
func iterativeBlockerSearch(g *Grid[rune], bytes FallingBytes, tf int) Point[rune] {
	for i, p := range bytes[tf+1:] {
		g.Set(p.Row, p.Col, p.Value)
		if isBlocked(g) {
			fmt.Printf("Blocked at %d: %d,%d\n", tf+i, p.Col, p.Row)
			return p
		}
	}
	panic("No blocker found")
}

func isBlocked(g *Grid[rune]) bool {
	return FindShortestPath(g, lessForAStar) == -1
}
```

It works but the result calculation takes around 2-3 seconds.

### Greedy A*
In this part we don't need to know the shortest path. Our goal is to determine if any
path is possible. If we set our comparison function to check only A* heuristic metric
we can find some (non-optimal) path quite fast:

```go
func isBlocked(g *Grid[rune]) bool {
	return FindShortestPath(g, lessForGreedyAStar) == -1
}

func lessForGreedyAStar(a, b Step) bool {
	return a.Metric < b.Metric
}
```

This will speed up the search to 0.5-1 second.

### Binary search
But we can do even better. We know the full path is blocked at some point, we also know
all the bytes that are falling. We can use binary search to find the exact time frame
when the path is blocked:

```go
// This is a binary search implementation to find the blocker:
// https://en.wikipedia.org/wiki/Binary_search
// The idea is to block cells by clusters to find the blocker by log(n) steps.
// We also don't need to check starting timeframe bytes
func bisectBlockerSearch(g *Grid[rune], bytes FallingBytes, tf int) Point[rune] {
	start, end := tf+1, len(bytes)
	for start < end {
        // When the difference is 1 we are at the exact blocker point
		if end-start == 1 {
			fmt.Printf("Blocked at %d: %d,%d\n", start, bytes[start].Col, bytes[start].Row)
			return bytes[start]
		}
		mid := (start + end) / 2
		blockCells(g, bytes[start:mid])
		// This means we can block further aka we need to move mid to right
		if !isBlocked(g) {
			start = mid
			continue
		}
		// Otherwise we move mid to left and end to previous mid (bisect)
		// and free the cells from new mid to new end
		end = mid
		futureMid := (start + end) / 2
		freeCells(g, bytes[futureMid:end])
	}

	panic("No blocker found")
}


func blockCells(g *Grid[rune], toBlock FallingBytes) {
	for _, p := range toBlock {
		g.Set(p.Row, p.Col, p.Value)
	}
}

func freeCells(g *Grid[rune], toFree FallingBytes) {
	for _, p := range toFree {
		g.Set(p.Row, p.Col, EmptyChar)
	}
}
```

This optimization drops us even further to 2-4 ms.

## Tags
- grid
- a-star
- binary search
