# Day 8. Resonant Collinearity
- [AoC day page](https://adventofcode.com/2024/day/8)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/08_resonant)

We are on the roof of a top-secret Easter Bunny installation. And the description of
the task is a bit cryptic. We need to find the antinodes of the antennas:
```
antinode occurs at any point that is perfectly in line with two antennas of
the same frequency - but only when one of the antennas is twice as far away as the other.
This means that for any pair of antennas with the same frequency,
there are two antinodes, one on either side of them.
```

So for me it was much easier to understand the task when I've seen the examples:
```
..........
...#......
..........
....a.....
..........
.....a....
..........
......#...
..........
..........
```
And

```
..........
...#......
#.........
....a.....
........a.
.....a....
..#.......
......#...
..........
..........
```

It's the third day with a grid task. And I've updated the
[grid helper code](https://github.com/insomnes/aoc/blob/main/2024/08_resonant/solution/grid.go)

## Part One
In the first part we need to find the number of antinodes on the grid.

The solution is quite simple. We need to iterate over all pairs of antennas and calculate
the antinodes for each pair. The antinode is the next point after the reflection of the
antenna. The reflection is calculated as `a.Row - (b.Row - a.Row), a.Col - (b.Col - a.Col)`.
We also should not count the antinode twice:

```go
type AntenaMap struct {
	Antenas map[rune][]Antena
	Rows    int
	Cols    int
}

type ParsedInput = AntenaMap

func shouldCountPoint(p Point[rune], grid *Grid[bool]) bool {
	point, inside := grid.GetWithCheck(p.Row, p.Col)
	present := point.Value
	if inside && !present {
		grid.Set(p.Row, p.Col, true)
		return true
	}
	return false
}

func calculateAntiNodes(a, b Antena, grid *Grid[bool]) int {
	// Reflect the antenas by each other, to get the antinodes.
// "Reflection" is: a.Row - (b.Row - a.Row), a.Col - (b.Col - a.Col)
	antiA, antiB := a.ReflectPoint(b), b.ReflectPoint(a)

	antiCount := 0
	if shouldCountPoint(antiA, grid) {
		antiCount++
	}
	if shouldCountPoint(antiB, grid) {
		antiCount++
	}
	return antiCount
}

func PartOne(inp ParsedInput) int {
	defer Track(time.Now(), "PartOne")
	antenas := inp.Antenas
	grid := NewGridWithDefault(inp.Rows, inp.Cols, false)
	total := 0

	for _, points := range antenas {
		for i := 0; i < len(points)-1; i++ {
			for j := i + 1; j < len(points); j++ {
				a, b := points[i], points[j]
				total += calculateAntiNodes(a, b, grid)
			}
		}
	}

	return total
}
```

## Part Two
In the second part we found that the antinodes are not limited by one and are proceeding
on the same line and repeated distance by the resonant frequency. We need to find the
overall number of antinodes on the grid. And we need to account for the points on the
place of antennas in pairs:

```go
func calculateResonantAntinodes(a, b Antena, grid *Grid[bool]) int {
	// In this part point of the other antena counts as antinode too, so we set
	// respective starting antinode to each antena
	antiCount := 0
	antiCount += countAntiNodes(a, b, grid)
	antiCount += countAntiNodes(b, a, grid)
	return antiCount
}

func PartTwo(inp ParsedInput) int {
	defer Track(time.Now(), "PartTwo")
	antenas := inp.Antenas
	grid := NewGridWithDefault(inp.Rows, inp.Cols, false)
	total := 0

	for _, points := range antenas {
		for i := 0; i < len(points)-1; i++ {
			for j := i + 1; j < len(points); j++ {
				a, b := points[i], points[j]
				total += calculateResonantAntinodes(a, b, grid)
			}
		}
	}

	return total
}
```

## Tags
- grid
