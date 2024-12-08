# Day 6. Guard Gallivant
- [AoC day page](https://adventofcode.com/2024/day/6)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/06_guard)

Now we can also travel in time. We are in the alchemical laboratory in the past. And we
need to predict the guard's movements. Guard is very conventional and moves only in the
straight lines. Also if he hits the wall he turns 90 degrees to the right and continues
to move.

As mentioned [before](04_ceres.md) grid tasks are pretty common in AoC. This day's
[grid helper](https://github.com/insomnes/aoc/blob/main/2024/06_guard/solution/grid.go) 
is updated a bit.

## Part one
In the first part historians asks us to count all the cells in the grid which guard
visited at least once before going away from our "observable universe".

Parsing here is simple, obstacle slices are collected for the second part.

```go
type GuardMap struct {
	Map          [][]rune
	Guard        Point[rune]
	RowObstacles [][]Point[rune]
	ColObstacles [][]Point[rune]
}

type ParsedInput = GuardMap

func ParseInput(lines []string) (ParsedInput, error) {
	pixels := make([][]rune, len(lines))
	rowObstacles := make([][]Point[rune], len(lines))
	colObstacles := make([][]Point[rune], len(lines[0]))
	guard := Point[rune]{Row: -1, Col: -1, Value: '?'}

	for r, row := range lines {
		pLine := make([]rune, len(row))
		for c, char := range row {
			// In inputs starting guard is facing up
			if char == GuardUp {
				guard = Point[rune]{Row: r, Col: c, Value: char}
				pLine[c] = EmptyCell
				continue
			}
			if char == ObstacleCell {
				rowObstacles[r] = append(rowObstacles[r], Point[rune]{Row: r, Col: c, Value: char})
				colObstacles[c] = append(colObstacles[c], Point[rune]{Row: r, Col: c, Value: char})
			}
			pLine[c] = char
		}
		pixels[r] = pLine
	}
	if guard.Row == -1 {
		return GuardMap{}, fmt.Errorf("guard not found")
	}
	if len(pixels) != len(lines) {
		return GuardMap{}, fmt.Errorf("Wrong number of rows %d != %d", len(pixels), len(lines))
	}
	if len(pixels[0]) != len(lines[0]) {
		return GuardMap{}, fmt.Errorf(
			"Wrong number of columns %d != %d",
			len(pixels[0]),
			len(lines[0]),
		)
	}
	return GuardMap{
		Map:          pixels,
		Guard:        guard,
		RowObstacles: rowObstacles,
		ColObstacles: colObstacles,
	}, nil
}
```

Guard moves are mapped to the grid moves and the guard is turning to the right by the rules:

```go
const (
	GuardUp      rune = '^'
	GuardRight   rune = '>'
	GuardDown    rune = 'v'
	GuardLeft    rune = '<'
	ObstacleCell rune = '#'
	EmptyCell    rune = '.'
)

func mapGuardMove(r rune) GridMove {
	switch r {
	case GuardUp:
		return MoveUp
	case GuardRight:
		return MoveRight
	case GuardDown:
		return MoveDown
	case GuardLeft:
		return MoveLeft
	default:
		panic(fmt.Sprintf("Invalid guard direction: %c", r))
	}
}

// Guard is always turning to the right by the rules
func TurnGuard(g Point[rune]) Point[rune] {
	switch g.Value {
	case GuardUp:
		return Point[rune]{Row: g.Row, Col: g.Col, Value: GuardRight}
	case GuardRight:
		return Point[rune]{Row: g.Row, Col: g.Col, Value: GuardDown}
	case GuardDown:
		return Point[rune]{Row: g.Row, Col: g.Col, Value: GuardLeft}
	case GuardLeft:
		return Point[rune]{Row: g.Row, Col: g.Col, Value: GuardUp}
	default:
		panic(fmt.Sprintf("Invalid guard direction: %c", g.Value))
	}
}
```

To find the answer we prepare two grids: one for visited cells and one for the obstacles.
Then we move the guard step by step and count the visited cells. I believe this can be
optimized by using a sparse grid and tracing guard movements "rays" in it, but it's ok
for solving the part one:

```go
func PartOne(inp ParsedInput) int {
	grid, err := NewGridFromSlices(inp.Map)
	if err != nil {
		panic(fmt.Sprintf("creating grid: %v", err))
	}
	guard := inp.Guard
	visited := NewGridWithDefault(grid.Rows, grid.Columns, false)
	visited.Set(guard.Row, guard.Col, true)
    // Initial guard position is counted
	posCount := 1

	for {
		move := mapGuardMove(guard.Value)
		nextOnGrid, ok := grid.MovePoint(guard.Row, guard.Col, move)
		// Here our guard would move out of the grid and that's the finish
		if !ok {
			break
		}

		if nextOnGrid.Value == ObstacleCell {
			guard = TurnGuard(guard)
			continue
		}

		guard = guard.Move(move)
		if visited.Get(guard.Row, guard.Col).Value {
			continue
		}

		visited.Set(guard.Row, guard.Col, true)
		posCount++

	}

	return posCount
}
```

## Part two
Part two is trickier. Historians ask us to find the ways to force loop the guard. We need
to place obstacles in the grid to make the guard move in the loop.

To optimize loop-checking we can use a sparse grid. It's a grid where we store only
obstacles in the columns and rows. This way we can trace guard movements in the grid
without checking all the cells. To "trace" each of the guard move "rays" we need to
check initial guard position and direction. Based on that we can find the next obstacle
or it's absence and calculate the next guard position. To find the loop we need
to check if the guard visited the same cell twice (we can skip direction for this check).

```go

type SparseGrid struct {
	RowObstacles [][]Point[rune]
	ColObstacles [][]Point[rune]
}

func (sg *SparseGrid) TraceUntilExit(guard Point[rune]) Point[rune] {
	for {
		newGuard, ok := sg.Trace(guard)
		if !ok {
			break
		}
		guard = newGuard
	}
	return guard
}

func (sg *SparseGrid) CheckIfLoops(guard Point[rune]) bool {
	visited := make(map[[2]int]struct{})
	for {
		key := [2]int{guard.Row, guard.Col}
		if _, ok := visited[key]; ok {
			return true
		}
		newGuard, ok := sg.Trace(guard)
		if !ok {
			break
		}
		if newGuard.Row != guard.Row || newGuard.Col != guard.Col {
			visited[key] = struct{}{}
		}
		guard = newGuard
	}
	return false
}

func (sg *SparseGrid) Trace(guard Point[rune]) (Point[rune], bool) {
	switch guard.Value {
	case GuardUp:
		return sg.TraceUp(guard)
	case GuardRight:
		return sg.TraceRight(guard)
	case GuardDown:
		return sg.TraceDown(guard)
	case GuardLeft:
		return sg.TraceLeft(guard)
	default:
		panic(fmt.Sprintf("Invalid guard direction: %c", guard.Value))
	}
}

func (sg *SparseGrid) TraceDown(guard Point[rune]) (Point[rune], bool) {
	col := sg.ColObstacles[guard.Col]

	newGuard := Point[rune]{Row: -1, Col: -1, Value: guard.Value}
	if len(col) == 0 {
		return newGuard, false
	}
	if col[len(col)-1].Row < guard.Row {
		return newGuard, false
	}

	for _, obstacle := range col {
		if obstacle.Row >= guard.Row {
			newGuard.Row = obstacle.Row - 1
			newGuard.Col = guard.Col
			newGuard = TurnGuard(newGuard)
			return newGuard, true
		}
	}
	panic("unreachable")
}

// Other directions are similar
```

We also need to code obstacle setting and removing to have a possibility to check
different obstacle placements. I've used sorting for obstacles in rows and columns
for the sake of simplicity:

```go
func ComparePoints(a, b Point[rune]) int {
	if a.Row < b.Row {
		return -1
	}
	if a.Row > b.Row {
		return 1
	}
	if a.Col < b.Col {
		return -1
	}
	if a.Col > b.Col {
		return 1
	}
	return 0
}

func (sg *SparseGrid) SetObstacle(obstacle Point[rune]) {
	row := sg.RowObstacles[obstacle.Row]
	row = append(row, obstacle)
	slices.SortFunc(row, ComparePoints)
	sg.RowObstacles[obstacle.Row] = row

	col := sg.ColObstacles[obstacle.Col]
	col = append(col, obstacle)
	slices.SortFunc(col, ComparePoints)
	sg.ColObstacles[obstacle.Col] = col
}

func (sg *SparseGrid) RemoveObstacle(obstacle Point[rune]) {
	row := sg.RowObstacles[obstacle.Row]
	var newRow []Point[rune]
	for i, o := range row {
		if o.Row == obstacle.Row && o.Col == obstacle.Col {
			newRow = row[:i]
			newRow = append(newRow, row[i+1:]...)
			break
		}
	}
	sg.RowObstacles[obstacle.Row] = newRow

	col := sg.ColObstacles[obstacle.Col]
	var newCol []Point[rune]
	for i, o := range col {
		if o.Row == obstacle.Row && o.Col == obstacle.Col {
			newCol = col[:i]
			newCol = append(newCol, col[i+1:]...)
			break
		}
	}
	sg.ColObstacles[obstacle.Col] = newCol
}
```

Understanding all of the edge cases was really hard for me. I've spent a lot of time
to understand them and properly implement the solution. The hardest part was to understand
that we can't place obstacles on the cells we've already visited. With all the edge cases
in mind, the final solution is not that hard:

- *Step Movement*: The guard’s movement is emulated step-by-step.
- *Obstacle Placement*: Obstacles are placed only in unvisited cells to avoid breaking the space-time continuum.
- *Loop Detection*: After placing an obstacle, the guard’s path is checked for loops using the sparse grid.
- *Undo Placement*: If no loop is found, the obstacle is removed.

```go
func PartTwo(inp ParsedInput) int {
	defer Track(time.Now(), "PartTwo")

	sg := SparseGrid{RowObstacles: inp.RowObstacles, ColObstacles: inp.ColObstacles}

	grid, err := NewGridFromSlices(inp.Map)
	if err != nil {
		panic(fmt.Sprintf("creating grid: %v", err))
	}
	guard := inp.Guard

	posCount := 0

	visited := NewGridWithDefault(grid.Rows, grid.Columns, false)
	visited.Set(guard.Row, guard.Col, true)

	for {
		oldGuard := Point[rune]{Row: guard.Row, Col: guard.Col, Value: guard.Value}
		move := mapGuardMove(guard.Value)
		nextOnGrid, ok := grid.MovePoint(guard.Row, guard.Col, move)
		// Here our guard would move out of the grid and that's the finish
		if !ok {
			break
		}

		// If the next cell is an obstacle, we can skip all our calculations and
		// just turn the guard to the right
		if nextOnGrid.Value == ObstacleCell {
			guard = TurnGuard(guard)
			continue
		}
		visited.Set(oldGuard.Row, oldGuard.Col, true)

		guard = guard.Move(move)

		turnedGuard := TurnGuard(oldGuard)

		// If there is no obstacle for the turned guard to meet we can skip
		// calculating the loop too
		if _, inside := sg.Trace(turnedGuard); !inside {
			continue
		}
		// We can't set obstacle on one of the cells we already visited, otherwise
		// we would break space-time continuum. This also saves us checking if we
		// have placed obstacle on the same cell before. Cause we can't put obstacle
		// on the cell we've already visited, and the only way to put obstacle there
		// is in the very first time we meet this cell as our next step, otherwise
		// we would block our path in the past from the future.
		if visited.Get(nextOnGrid.Row, nextOnGrid.Col).Value {
			continue
		}

		sg.SetObstacle(Point[rune]{Row: nextOnGrid.Row, Col: nextOnGrid.Col, Value: ObstacleCell})
		loops := sg.CheckIfLoops(turnedGuard)
		sg.RemoveObstacle(
			Point[rune]{Row: nextOnGrid.Row, Col: nextOnGrid.Col, Value: ObstacleCell},
		)
		if loops {
			posCount++
		}

	}

	return posCount
}
```

## Tags
- grid
- sparse grid
- tracing
