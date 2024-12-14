# Day 14. Restroom Redoubt
- [AoC day page](https://adventofcode.com/2024/day/14)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/14_restroom)

Historians need a bathroom break and we need to help them to avoid the new Easter Bunny
Headquarters bathroom guard robots. Robots move in straight lines and have constant speed.
They also have teleports to not crash into the walls.

## Part One
In the first part, we need to calculate the safety factor by predicting all the robots
position after 100 seconds.

Robot movement pattern is simple and we can skip step-by-step simulation and calculate
position on arbitrary time step directly. When robot reaches the wall, it teleports
to the other side, so we can use modulo operation for our calculations:

```go
type Robot struct {
	Row, Col   int
	VelR, VelC int
}

func (r Robot) Simulate(modRow int, modCol int, ticks int) Robot {
	if ticks <= 0 {
		panic(fmt.Sprintf("Invalid number of ticks: %d", ticks))
	}

	rowDelta := calculateDelta(r.VelR, ticks, modRow)
	newRow := modAdd(r.Row, rowDelta, modRow)

	colDelta := calculateDelta(r.VelC, ticks, modCol)
	newCol := modAdd(r.Col, colDelta, modCol)

	return Robot{Row: newRow, Col: newCol, VelR: r.VelR, VelC: r.VelC}
}

// In go `-7 % 5` is -2, so we use modulo arythmetic properties
// to get the positive result
func calculateDelta(velocity int, ticks int, mod int) int {
	delta := velocity * ticks % mod
	if delta < 0 {
		delta += mod
	}
	return delta
}

func modAdd(a int, b int, mod int) int {
	res := (a + b) % mod
	if res < 0 {
		res += mod
	}
	return res
}
```

Main function and safety factor calculation are also straightforward:

```go
const (
	testRows  = 7
	testCols  = 11
	inputRows = 103
	inputCols = 101
)

type ParsedInput = []Robot

const partOneSteps = 100

func PartOne(inp ParsedInput) int {
	defer Track(time.Now(), "PartOne")
	rows, cols := inputRows, inputCols

	robots := slices.Clone(inp)
	simulated := make([]Robot, len(robots))
	for i, robot := range robots {
		simulated[i] = robot.Simulate(rows, cols, partOneSteps)
	}

	sf := safetyFactor(rows, cols, simulated)

	return sf
}

func getQuadrant(midRow, midCol int, r Robot) int {
	if r.Row == midRow || r.Col == midCol {
		panic(fmt.Sprintf("middle row or column: %s", r))
	}
	if r.Row < midRow {
		if r.Col < midCol {
			return 0
		}
		return 1
	}
	if r.Col < midCol {
		return 2
	}
	return 3
}

func safetyFactor(rows, cols int, robots []Robot) int {
	// Odd number by task rules, so to find the middle we can just divide by 2
	midRow, midCol := rows/2, cols/2
	quadrants := make([]int, 4)
	for _, r := range robots {
		if r.Row == midRow || r.Col == midCol {
			continue
		}
		q := getQuadrant(midRow, midCol, r)
		quadrants[q] += 1
	}
	sf := 1
	for _, q := range quadrants {
		sf *= q
	}

	return sf
}
```

## Part Two
In the second part someone mentions that these robots are similar to the ones they use
in the North Pole. Those models have an easter egg feature: very rarely they may arrange
themseves in a Christmas tree shape. We need to find how long would it take.

The pattern is unknown and time to wait may be very long. We can't look at all the
possible time steps, so we need to find some flag to stop the simulation and show us 
current state. My first guess was that christmas tree needs to have a vertical trunk.
So I've decided to look for the vertical sequence of 10 robots in the same column.
And to my surprise, it worked on the first try:

```go
func (r Robot) ToKey() int {
	return toKey(r.Row, r.Col)
}

func toKey(row, col int) int {
	return row*100000 + col
}


const (
	trunkSeqSize = 10
	printTree    = true
)

func PartTwo(inp ParsedInput) int {
	defer Track(time.Now(), "PartTwo")
	rows, cols := inputRows, inputCols

	robots := slices.Clone(inp)
	for sec := 1; sec <= 100000; sec++ {
		robotsByCol := make([][]int, cols)
		for i, robot := range robots {
			newRobot := robot.Simulate(rows, cols, 1)
			robotsByCol[newRobot.Col] = append(robotsByCol[newRobot.Col], newRobot.Row)
			robots[i] = newRobot
		}

		for c, column := range robotsByCol {
			slices.Sort(column)
			if !findSequence(column, trunkSeqSize) {
				continue
			}
			if printTree {
				fmt.Println(StringForTree(robots, rows, cols))
				fmt.Printf("\n%d sec, found %d in column %d:\n%v\n", sec, trunkSeqSize, c, column)
			}
			return sec
		}

	}

	return 0
}

func findSequence(toCheck []int, size int) bool {
	if len(toCheck) < size {
		return false
	}
	foundSize := 1
	previous := toCheck[0]

	for i := 1; i < len(toCheck); i++ {
		if i+size >= len(toCheck) {
			return false
		}
		num := toCheck[i]
		if num == previous {
			continue
		}
		if num == previous+1 {
			foundSize++
		} else {
			foundSize = 1
		}
		previous = num
		if foundSize == size {
			return true
		}
	}

	return false
}

func StringForTree(robots []Robot, rows, cols int) string {
	var sb strings.Builder

	counts := make(map[int]int8)
	for _, robot := range robots {
		key := robot.ToKey()
		counts[key] += 1
	}

	for r := range rows {
		for c := range cols {
			if val, ok := counts[toKey(r, c)]; ok && val > 0 {
				if val > 9 {
					panic(fmt.Sprintf("Too many robots at %d,%d: %d", r, c, val))
				}
				sb.WriteRune('#')
				continue
			}
			sb.WriteRune('.')
		}
		sb.WriteRune('\n')
	}

	return sb.String()
}
```

## Tags
- visualization
- modulo operations
