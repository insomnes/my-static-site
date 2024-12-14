# Day 12. Garden Groups
- [AoC day page](https://adventofcode.com/2024/day/12)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/12_garden)

We need to help gardener on calculating the price for the garden plots fencing.
Each plot has only one plant (letter). Regions are formed by plots of the same
type that touch either horizontally or vertically.

This is again a [grid related problem](https://github.com/insomnes/aoc/blob/main/2024/12_garden/solution/grid.go).

## Part One
In this part we calculate the price as `Area * Perimeter`.
The area is the number of plants in the plot. And the perimeter is the number of "borders".
Each plot has a border if it touches the plot of another type or the edge of the grid.

If the task would not include condition that one region can have enclave of another region,
we could just use [Pick's theorem](https://en.wikipedia.org/wiki/Pick%27s_theorem)
to calculate the area and perimeter.

With the enclave condition we can iterate over the grid and for each unvisited plot
we start the flood fill algorithm to find the region and it's properties. During the 
region search we mark the visited plots to avoid checking them on the main loop.

```go
type GardenMap struct {
	Map [][]rune
}

type ParsedInput = GardenMap

...

func PartOne(inp ParsedInput) int {
	total := 0
	grid, err := NewGridFromSlices(inp.Map)
	if err != nil {
		panic(fmt.Sprintf("creating grid %s", err))
	}

	visited := NewGridWithDefault(grid.Rows, grid.Columns, false)

	for pi, point := range grid.Cells {
		if visited.Cells[pi].Value {
			continue
		}

		area, perimeter := findFullPlot(grid, visited, point)
		total += area * perimeter
	}

	return total
}
const cellSides = 4

// area, perimeter
func findFullPlot(grid *Grid[rune], globalVisited *Grid[bool], start Point[rune]) (int, int) {
	queue := make([]Point[rune], 0, 16)
	queue = append(queue, start)

	area, perimeter := 0, 0

	for len(queue) > 0 {
		point := queue[0]
		queue = queue[1:]
		if globalVisited.Get(point.Row, point.Col).Value {
			continue
		}

		globalVisited.Set(point.Row, point.Col, true)
		area++

		nCode, polyNeighbors := encodePointNeighbors(grid, point)
		cellPerimiter := calcPerimeter(nCode)
		perimeter += cellPerimiter

		for _, neighbor := range polyNeighbors {
			queue = append(queue, neighbor)
		}
	}

	return area, perimeter
}
```

I've done each plot perimeter calculation a bit complicated way by encoding the cell
neighbors and checking the bit mask for the borders. But this will be useful for the
next part of the task:

```go
func encodePointNeighbors(grid *Grid[rune], point Point[rune]) (int, []Point[rune]) {
	// 0 1 2
	// 3 X 4
	// 5 6 7
	row, col := point.Row, point.Col
	moves := []GridMove{
		MoveUpLeft, MoveUp, MoveUpRight,
		MoveLeft, MoveRight,
		MoveDownLeft, MoveDown, MoveDownRight,
	}

	name := point.Value

	codedNeighbors := 0
	crossNeighbors := make([]Point[rune], 0, 4)

	for i, move := range moves {
		nPoint := grid.GetAnyByMove(row, col, move)
		if nPoint.Value != name {
			codedNeighbors |= 1 << i
			continue
		}
		if move == MoveUp || move == MoveRight || move == MoveDown || move == MoveLeft {
			crossNeighbors = append(crossNeighbors, nPoint)
		}
	}

	return codedNeighbors, crossNeighbors
}

// Each cell has 1 bit around
// 0 1 2
// 3 X 4
// 5 6 7
// So we can use bit mask to find the borders by setting
// the bits for each neighbor: 0 for the same name, 1 for different
func prepareByte(powers []int) int {
	mask := 0
	for _, power := range powers {
		if power < 0 || power > 7 {
			panic(fmt.Sprintf("invalid power %d", power))
		}
		mask |= 1 << power
	}
	return mask
}

var (
	// 2, 16, 64, 8
	upBorderMask    int = prepareByte([]int{1})
	rightBorderMask int = prepareByte([]int{4})
	downBorderMask  int = prepareByte([]int{6})
	leftBorderMask  int = prepareByte([]int{3})
)

func calcPerimeter(nCode int) int {
	perimeter := 0
	for _, mask := range borderMasks {
		if nCode&mask == mask {
			perimeter++
		}
	}
	return perimeter
}
```

## Part Two
The formula has changed to `Area * Sides`. Each straight fence line is the side.
This adds some complexity. But we can use the fact that polygon side count is equal
to the number of corners because each angle represents a change in direction of the fence.
And again enclaves complicate the task because we need to track inner corners as well.
So we check the triplets of the cell neighbors and match them to the possible
corner types by the bit mask:

```go
	upLeftMask    int = prepareByte([]int{0, 1, 3})
	upRightMask   int = prepareByte([]int{1, 2, 4})
	downRightMask int = prepareByte([]int{4, 6, 7})
	downLeftMask  int = prepareByte([]int{3, 5, 6})

	// 1 0 .
	// 0 X .
	upLeftInner int = prepareByte([]int{0})
	// 1 1 .
	// 1 X .
	upLeftOuter int = prepareByte([]int{0, 1, 3})
	// . 1 .
	// 1 X .
	upLeftInside int = prepareByte([]int{1, 3})

	// . 0 1
	// . X 0
	upRightInner int = prepareByte([]int{2})
	// . 1 1
	// . X 1
	upRightOuter int = prepareByte([]int{1, 2, 4})
	// . 1 .
	// . X 1
	upRightInside int = prepareByte([]int{1, 4})

	// . X 0
	// . 0 1
	downRightInner int = prepareByte([]int{7})
	// . X 1
	// . 1 1
	downRightOuter int = prepareByte([]int{4, 6, 7})
	// . X 1
	// . 1 .
	downRightInside int = prepareByte([]int{4, 6})

	// 0 X .
	// 1 0 .
	downLeftInner int = prepareByte([]int{5})
	// 1 X .
	// 1 1 .
	downLeftOuter int = prepareByte([]int{3, 5, 6})
	// 1 X .
	// . 1 .
	downLeftInside int = prepareByte([]int{3, 6})
)

func findAngles(nCode int) int {
	angles := 0
	upLeft := nCode & upLeftMask
	upRight := nCode & upRightMask
	downRight := nCode & downRightMask
	downLeft := nCode & downLeftMask

	if upLeft == upLeftOuter || upLeft == upLeftInner || upLeft == upLeftInside {
		angles++
	}

	if upRight == upRightOuter || upRight == upRightInner || upRight == upRightInside {
		angles++
	}

	if downRight == downRightOuter || downRight == downRightInner || downRight == downRightInside {
		angles++
	}

	if downLeft == downLeftOuter || downLeft == downLeftInner || downLeft == downLeftInside {
		angles++
	}

	return angles
}
```

The rest of the code is similar to the first part. We just need to replace the perimeter
calculation with the angles calculation:

```go
func PartTwo(inp ParsedInput) int {
	total := 0
	grid, err := NewGridFromSlices(inp.Map)
	if err != nil {
		panic(fmt.Sprintf("creating grid %s", err))
	}

	visited := NewGridWithDefault(grid.Rows, grid.Columns, false)

	for pi, point := range grid.Cells {
		if visited.Cells[pi].Value {
			continue
		}
		// We can calculate sides by finding angles count
		area, sides := findFullPlotWithSides(grid, visited, point)
		total += area * sides

	}

	return total
}

// area, sides
func findFullPlotWithSides(
	grid *Grid[rune],
	globalVisited *Grid[bool],
	start Point[rune],
) (int, int) {
	queue := make([]Point[rune], 0, 16)
	queue = append(queue, start)

	area := 0
	angles := 0

	for len(queue) > 0 {
		point := queue[0]
		queue = queue[1:]

		if globalVisited.Get(point.Row, point.Col).Value {
			continue
		}
		globalVisited.Set(point.Row, point.Col, true)
		area++

		nCode, polyNeighbors := encodePointNeighbors(grid, point)
		// how many sides our polygon has can be calculated by the number of angles it has
		pAngles := findAngles(nCode)
		angles += pAngles

		for _, neighbor := range polyNeighbors {
			queue = append(queue, neighbor)
		}
	}

	return area, angles
}
```

## Tags
- grid
- flood fill
- bitmasks
