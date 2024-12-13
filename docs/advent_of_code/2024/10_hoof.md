# Day 10. Hoof It
- [AoC day page](https://adventofcode.com/2024/day/10)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/10_hoof)

We have arrived at the famous lava production facility on Lava Island,
and the reindeer need our help

Our task is to find hike paths from 0 to 9 (0->1->2...->9) on the grid.

[Grid time again.](https://github.com/insomnes/aoc/blob/main/2024/10_hoof/solution/grid.go)

## Part One
In the first part we need to count and sum all reachable 9s for each 0. At the input
parsing stage we are collecting all 0 points to iterate over them later. For each 0,
we find all 9s reachable from it through recursive calls to consecutive neighbors
of the current point. We store the 9s in a set to avoid counting them multiple times.
For each point we store the set of nines in the cache to not recalculate them again:

```go
type HikingMap struct {
	Map        [][]int8
	ZeroPoints []Point[int8]
}

type ParsedInput = HikingMap

...

func PartOne(inp ParsedInput) int {
	defer Track(time.Now(), "PartOne")
	total := 0
	grid, err := NewGridFromSlices(inp.Map)
	if err != nil {
		panic(fmt.Sprintf("creating grid %s", err))
	}
	cache := NewGridWithDefault[map[[2]int]struct{}](grid.Rows, grid.Columns, nil)

	for _, zp := range inp.ZeroPoints {
		total += len(findNines(grid, zp, cache))
	}

	return total
}

func findNines(
	grid *Grid[int8],
	point Point[int8],
	cache *Grid[map[[2]int]struct{}],
) map[[2]int]struct{} {
	if point.Value == 9 {
		return map[[2]int]struct{}{{point.Row, point.Col}: {}}
	}
	if val := cache.Get(point.Row, point.Col).Value; val != nil {
		return val
	}
	nines := make(map[[2]int]struct{})
	for _, neighbor := range grid.GetNeighborsCross(point.Row, point.Col) {
		if neighbor.Value != point.Value+1 {
			continue
		}

		for p := range findNines(grid, neighbor, cache) {
			nines[p] = struct{}{}
		}
	}
	cache.Set(point.Row, point.Col, nines)
	return nines
}
```

## Part Two
Part two is even simpler, in my opinion. We need to find all the distinct paths from 0 to all
9s. We store only the number of ways from the point to 9s in the cache. The rest is
the same as in part one, but we don’t need to update the set, which makes it run faster:

```go
func PartTwo(inp ParsedInput) int {
	defer Track(time.Now(), "PartTwo")
	total := 0
	grid, err := NewGridFromSlices(inp.Map)
	if err != nil {
		panic(fmt.Sprintf("creating grid %s", err))
	}

	cache := NewGridWithDefault(grid.Rows, grid.Columns, -1)

	for _, zp := range inp.ZeroPoints {
		total += findDistinctWays(grid, zp, cache)
	}

	return total
}

func findDistinctWays(grid *Grid[int8], point Point[int8], cache *Grid[int]) int {
    // No need to check the cache here, we can just return 1 for 9
	if point.Value == 9 {
		return 1
	}
	cached := cache.Get(point.Row, point.Col).Value
	if cached != -1 {
		return cached
	}

	ways := 0
	for _, neighbor := range grid.GetNeighborsCross(point.Row, point.Col) {
		if neighbor.Value != point.Value+1 {
			continue
		}
		ways += findDistinctWays(grid, neighbor, cache)
	}
	cache.Set(point.Row, point.Col, ways)
	return ways
}
```

## Tags
- recursion
- memoization
- grid
- pathfinding
