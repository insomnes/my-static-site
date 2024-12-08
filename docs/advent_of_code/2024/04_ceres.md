# Day 4. Ceres Search
- [AoC day page](https://adventofcode.com/2024/day/4)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/04_ceres)

## Part one
The elf on the Ceres monitoring station needs our help to find the word XMAS on the text grid.
This is the first task of the 2024 AoC which requires grid. For every year it's nice
to have convenient [grid helpers](https://github.com/insomnes/aoc/blob/main/2024/04_ceres/solution/grid.go).
I also use one dimensional slice to represent the grid, cause it's usually faster to 
access elements in one memory segment.

The task is simple: find the word XMAS on the grid. But I've missed the fact that
the word should be written only in lines first (but can be backwards). So the correct
variants examples would be:
```
S..S..S
.A.A.A.
..MMM..
SMAXMAS
..MMM..
.A.A.A.
S..S..S
```


First we need to parse the input to grid:

```go
type ParsedInput = Grid[rune]

const (
	X = 'X'
	M = 'M'
	A = 'A'
	S = 'S'
)

func ParseInput(lines []string) (ParsedInput, error) {
	defer Track("ParseInput")()
	rows, columns := len(lines), len(lines[0])
	g := NewGrid[rune](rows, columns)

	for row, line := range lines {
		if len(line) != columns {
			return Grid[rune]{}, fmt.Errorf(
				"Bad %dth line length: %d != %d",
				row,
				len(line),
				columns,
			)
		}
		for col, r := range line {
			g.Set(row, col, r)
		}
	}

	return *g, nil
}
```

To find the XMAS word we need to iterate over the grid and check if the current point
is the first letter of the word and find all correct paths from this point:

```go
func PartOne(inp ParsedInput) int {
	xmasCount := 0

	for row := 0; row < inp.Rows; row++ {
		for col := 0; col < inp.Columns; col++ {
			point := inp.Get(row, col)
			if point.Value != X {
				continue
			}
			paths := findXMASPathsCount(&inp, point)
			xmasCount += paths
		}
	}

	return xmasCount
}
```

To find all paths we iterate over possible "line" moves on grid like `[-1 0]` left,
`[1 1]` right-down, etc. And check the next letter in the direction of the move until
we find the last letter of the word. If we find it, we increment the paths counter.
And that's it:

```go
func findXMASPathsCount(g *Grid[rune], point Point[rune]) int {
	paths := 0

	for _, move := range GridAllMoves {
		row, col := point.Row, point.Col
	CharLoop:
		for _, char := range []rune{M, A, S} {
			row, col = row+move[0], col+move[1]
			nextPoint, ok := g.GetWithCheck(row, col)
			if !ok || nextPoint.Value != char {
				break CharLoop
			}
			if char == S {
				paths++
			}
		}
	}

	return paths
}
```

## Part two
Looks like we have misunderstood the elf's task. It's not `XMAS` puzzle, but `X-MAS` puzzle.
That means we need to find `MAS` in the shape of `X` letter. So the correct variants would be:
```
M.M  M.S  S.S  S.M
.A.  .A.  .A.  .A.
S.S  M.S  M.M  S.M
```

The core loop is the same as in the first part, but now we are looking for `A` letter.
And if we find it, we check the up-left and up-right directions for `M` or `S` letters:

```go
func PartTwo(inp ParsedInput) int {
	masCount := 0

	// We can skip first and last row and column for A search, caue it's 3x3 square:
	// M . S
	// . A .
	// M . S
	for row := 1; row < inp.Rows-1; row++ {
		for col := 1; col < inp.Columns-1; col++ {
			point := inp.Get(row, col)
			if point.Value != A {
				continue
			}
			if findMAS(&inp, point) {
				masCount++
			}
		}
	}

	return masCount
}

func findMAS(g *Grid[rune], point Point[rune]) bool {
	return checkUpLeft(g, point) && checkUpRight(g, point)
}
```

The check is simple:

- Is the corner on grid?
- Is the corner letter `M` or `S` (check needed opposite corner letter)?
- Is the opposite corner on grid?
- Is the opposite corner letter correct?

```go
func checkUpLeft(g *Grid[rune], point Point[rune]) bool {
	upLeft, ok := g.GetUpLeft(point.Row, point.Col)
	expectedDownRight := getMASmissing(upLeft.Value)

	if !ok || expectedDownRight == notMASchar {
		return false
	}
	downRight, ok := g.GetDownRight(point.Row, point.Col)
	if !ok || downRight.Value != expectedDownRight {
		return false
	}
	return true
}

func checkUpRight(g *Grid[rune], point Point[rune]) bool {
	upRight, ok := g.GetUpRight(point.Row, point.Col)
	expectedDownLeft := getMASmissing(upRight.Value)
	if !ok || expectedDownLeft == notMASchar {
		return false
	}

	downLeft, ok := g.GetDownLeft(point.Row, point.Col)
	if !ok || downLeft.Value != expectedDownLeft {
		return false
	}

	return true
}

const notMASchar = '-'

func getMASmissing(c rune) rune {
	switch c {
	case M:
		return S
	case S:
		return M
	default:
		return notMASchar
	}
}
```

## Tags
- grid
- sequence search
