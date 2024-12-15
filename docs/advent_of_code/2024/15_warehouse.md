# Day 15. Warehouse Woes
- [AoC day page](https://adventofcode.com/2024/day/15)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/15_warehouse)

Magic submarine is back and familiar lanternfish schools but the problem is different.
They need help with broken robot that is supposed to move boxes around
the warehouse. We have robot movements and need to predict it's final position.

[This is a grid problem again.](https://github.com/insomnes/aoc/blob/main/2024/15_warehouse/solution/grid.go)

## Part One
Part one is straightforward. Box can move next box in line in the direction of movement.
If there is the wall in the way, we can't move the box:
```go
func moveRobot(grid *WhsGrid, robot Cell, move GridMove) Cell {
	next := grid.GetAnyByMove(robot.Row, robot.Col, move)
	if next.Value == EmptyChar {
		next.Value = RobotChar
		return next
	}
	if next.Value == WallChar {
		return robot
	}

	endCell := findBoxChainEnd(grid, next, move)
	if endCell.Value != EmptyChar {
		return robot
	}
	// Moving straight line of the boxes in our case can be coded as
	// "teleporting" the first box to the end of the chain. For our purposes
	// any box marker is indistinguishable from other boxes
	grid.Set(next.Row, next.Col, EmptyChar)
	grid.Set(endCell.Row, endCell.Col, BoxChar)

	next.Value = RobotChar
	return next
}

// Check next cell in the direction of the move until we hit a wall or empty cell
func findBoxChainEnd(grid *WhsGrid, startBox Cell, move GridMove) Cell {
	current, next := startBox, startBox
	for next.Value != WallChar && next.Value != EmptyChar {
		next = grid.GetAnyByMove(current.Row, current.Col, move)
		current = next
	}
	return current
}

```

So we simulate all the moves and calculate the required score:

```go
type (
	WhsGrid = Grid[rune]
	Cell    = Point[rune]
)

type WarehouseInfo struct {
	Map   [][]rune
	Moves []GridMove
	Robot Cell
}

type ParsedInput = WarehouseInfo

...

func PartOne(inp ParsedInput) int {
	robot := inp.Robot
	grid, err := NewGridFromSlices(inp.Map)
	if err != nil {
		panic(fmt.Sprintf("creating grid: %s", err))
	}

	// We can check if the move is the same, but it's quite fast as is
	for _, move := range inp.Moves {
		robot = moveRobot(grid, robot, move)
	}
	return calculateGPS(grid, BoxChar)
}

...

func calculateGPS(g *WhsGrid, boxChar rune) int {
	gps := 0
	for _, cell := range g.Cells {
		if cell.Value != boxChar {
			continue
		}
		gps += calcCellGPS(cell)
	}
	return gps
}

func calcCellGPS(cell Cell) int {
	return 100*cell.Row + cell.Col
}
```

## Part Two
Twist of the second part is that we have another warehouse with the same robot moves,
but this warehouse has twice as many columns in it's grid. So now boxes take two
cells: `[]`. Robot still moves one grid cell at a time: `.@[]..` => `..@[].`

This complicates horizontal movement a bit:

```go
// Horizontal move is very similar to the PartOne's moveRobot, but we need to
// account for the new box size and recursively move all boxes in the chain
func moveBoxHorizontally(grid *WhsGrid, box Cell, move GridMove) bool {
	// In the end of the box chain we can decide if we can move all previous boxes
	// based on the next cell value
	if box.Value == EmptyChar || box.Value == WallChar {
		return box.Value == EmptyChar
	}
	side := toOtherBoxSide(box)
	next := grid.GetAnyByMove(box.Row, side.Col, move)
	if !moveBoxHorizontally(grid, next, move) {
		return false
	}

	grid.Set(next.Row, next.Col, side.Value)
	grid.Set(box.Row, side.Col, box.Value)
	grid.Set(box.Row, box.Col, EmptyChar)
	return true
}
```

Because vertical movement of the one box can now in some cases cause movement of the two
boxes:
```
......       ......
......       .[][].
.[][].   ^   ..[]..
..[]..   |   ..@...
..@...       ......
```

We also need to account for all stacked boxes for the collision detection:
```
.........
..#......
..[][][].
...[][]..
....[]...
.....@...
```

First of all we need mechanism to determine our box stack
(each part of the box separately):

```go
// This is kind of a BFS, but with the specific neighbor finding
func findStackedParts(grid *WhsGrid, part Cell, move GridMove) []Cell {
	visited := make(map[int]struct{})

	sidePart := toOtherBoxSide(part)
	parts := make([]Cell, 0)
	queue := []Cell{part, sidePart}

	for len(queue) > 0 {
		// It is important to stack the boxes in the BFS order, layer by layer
		cur := queue[0]
		queue = queue[1:]
		key := calcCellGPS(cur)
		if _, ok := visited[key]; ok {
			continue
		}
		visited[key] = struct{}{}
		parts = append(parts, cur)

		following := findFollowingParts(grid, cur, move)
		if len(following) == 1 {
			return []Cell{}
		}

		for _, neighbor := range following {
			if _, ok := visited[calcCellGPS(neighbor)]; ok {
				continue
			}
			queue = append(queue, neighbor)
		}
	}
	return parts
}

func findFollowingParts(grid *WhsGrid, box Cell, move GridMove) []Cell {
	following := grid.GetAnyByMove(box.Row, box.Col, move)
	if following.Value == EmptyChar {
		return []Cell{}
	}
	if following.Value == WallChar {
		return []Cell{following}
	}
    // toOtherBoxSide is a helper function to get the other part of the box
    // with proper symbol and coordinates
	return []Cell{following, toOtherBoxSide(following)}
}
```

I think solution can be optimized with only one go through all the stack parts 
via recursive move function, but this one is fast and simple enough too.

With the stack of all parts found we can move them one by one in the reverse order:
```go
func movePartVertically(grid *WhsGrid, box Cell, move GridMove) bool {
	stackedParts := findStackedParts(grid, box, move)
	if len(stackedParts) == 0 {
		return false
	}

	// It is important to move boxes from the far end of the stack
	for i := len(stackedParts) - 1; i >= 0; i-- {
		stackedPart := stackedParts[i]
		movePart(grid, stackedPart, move)
	}
	return true
}

func movePart(grid *WhsGrid, part Cell, move GridMove) {
	if part.Value != LboxChar && part.Value != RboxChar {
		panic(fmt.Sprintf("moving box %c at %d, %d", part.Value, part.Row, part.Col))
	}
	next := grid.GetAnyByMove(part.Row, part.Col, move)
	if next.Value != EmptyChar {
		panic(fmt.Sprintf("move to '%c' at %d, %d", next.Value, next.Row, next.Col))
	}

	grid.Set(next.Row, next.Col, part.Value)
	grid.Set(part.Row, part.Col, EmptyChar)
}
```

The main function is similar to the first part, but with choosing the correct movement
function based on the move direction:

```go
func PartTwo(inp ParsedInput) int {
	grid := expandWarehouse(inp.Map)
	// Expanded warehouse means that we need to double robot's starting column
	robot, moves := inp.Robot, inp.Moves
	robot.Col = robot.Col * 2

	for _, move := range moves {
		robot = moveRobotWide(grid, robot, move)
	}
    // Score is calculated based on the left part of the box
	return calculateGPS(grid, LboxChar)
}

func moveRobotWide(grid *WhsGrid, robot Cell, move GridMove) Cell {
	next := grid.GetAnyByMove(robot.Row, robot.Col, move)
	if next.Value == WallChar {
		return robot
	}
	if next.Value == EmptyChar || tryMoveBox(grid, next, move) {
		robot.Row, robot.Col = next.Row, next.Col
	}
	return robot
}

func tryMoveBox(grid *WhsGrid, box Cell, move GridMove) bool {
	if move == MoveLeft || move == MoveRight {
		return moveBoxHorizontally(grid, box, move)
	}
	return movePartVertically(grid, box, move)
}
```

## Tags
- grid
- collision detection
