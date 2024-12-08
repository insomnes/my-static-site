# Day 2. Red-Nosed Reports
- [AoC day page](https://adventofcode.com/2024/day/2)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/02_reports)

## Part one
The nuclear fusion/fission plant engineers have provided us data reports and we need
to validate levels in reports by provided rules. The rules are simple:

- All numbers in the list are increasing or decreasing
- Any two adjacent numbers in the list differ by at least 1 and at most 3

We need to count the number of the safe reports. This is pretty straightforward:

```go
type ParsedInput = [][]int


func isDeltaValid(delta int) bool {
	return abs(delta) >= 1 && abs(delta) <= 3
}

// This function helps to check if the deltas have the same sign
func areDeltasSafe(delta, prevDelta int) bool {
	return delta*prevDelta >= 0 && isDeltaValid(delta)
}

func isRowSafe(row []int) bool {
	prev := row[0]
	prevDelta := 0
	for _, n := range row[1:] {
		delta := n - prev
		if !areDeltasSafe(delta, prevDelta) {
			return false
		}

		prev, prevDelta = n, delta
	}
	return true
}

func PartOne(inp ParsedInput) int {
	safe := 0
	for _, row := range inp {
		if isRowSafe(row) {
			safe++
		}
	}
	return safe
}
```

## Part two
Now one of our numbers (level) in each report can be skipped but only once. And we should define
if the level is safe by the same rules as in part one. The task can be solved by the simple
brute force approach. We can check if full row is safe and then check each of the new
row variotions with the skipped level. If any of the variations is safe we can return true:

```go
func IsRowSafeWithSkipBrute(row []int) bool {
	if isRowSafe(row) {
		return true
	}

	for i := 0; i < len(row); i++ {
		skip := slices.Concat(row[:i], row[i+1:])
		if isRowSafe(skip) {
			return true
		}
	}

	return false
}
```

But I have implemented another approach with Depth First Search on the state space.

The state is defined by the first, previous, current and next levels in the row. It also
has a flag to indicate if the level was skipped before. The `isSafe` method here was
really hard for me to come around. Cause each skip can change the level trend and we need
to comply with the first change, but also the first element may be deleted and also has
the same value as the second one. Brrrr... All of these conditions are result of my
trial and error approach to understand the task flow. 

Bruteforce approach is much simpler and more readable. I also think on this data size
it is faster. But I've decided to keep the DFS approach for the sake of learning.

```go
type State struct {
	fv   int
	pi   int
	ci   int
	ni   int
	skip bool
}

func (s *State) isSafe(row []int) bool {
	if s.ci >= len(row) {
		return true
	}

	delta := row[s.pi] - row[s.ci]
	if !isDeltaValid(delta) {
		return false
	}

	if (s.pi == 0 && row[s.pi] == s.fv) || (s.pi == 1 && row[s.pi] == s.fv) {
		return true
	}

	trend := s.fv - row[s.pi]

	if trend*delta < 0 {
		return false
	}

	return true
}

func (s *State) next() {
	s.pi = s.ci
	s.ci = s.ni
	s.ni++
}

// The way you want to handle the skip is very important to the nature of your conditions
// in isSafe method
// I've decided to skip the current level and check the next one
func (s *State) createSkip() State {
	return State{
		fv:   s.fv,
		pi:   s.pi,
		ci:   s.ni,
		ni:   s.ni + 1,
		skip: true,
	}
}
```

When we have safe logic checking and all helpers solving the task is just DFS before
we've reached the end of the row. The important part here is to initialize our queue
with the skipped first level-row (will be checked later in case of not safe row) and
the full row. This manual intervention is much more simple and robust than my previous
attempts to calculate the first skipped level.

```go
func IsRowSafeWithSkip(row []int) bool {
	queue := make(Stack, 0, len(row)*2)
	// LIFO
	queue.Push(State{fv: row[1], pi: 1, ci: 2, ni: 3, skip: true})
	queue.Push(State{fv: row[0], pi: 0, ci: 1, ni: 2, skip: false})

	for len(queue) > 0 {
		state := queue.Pop()

		safe := state.isSafe(row)
		// LIFO
		if !state.skip {
			queue.Push(state.createSkip())
		}

		if safe {
			if state.ci >= len(row) {
				return true
			}
			state.next()
			queue.Push(state)
		}

	}
	return false
}

func PartTwo(inp ParsedInput) int {
	defer Track("PartTwo")()

	safe := 0
	for _, row := range inp {
		if IsRowSafeWithSkip(row) {
			safe++
		}
	}
    return safe
}
```

## Tags
- backtracking
- DFS
- state space
