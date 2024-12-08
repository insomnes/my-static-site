# Day 3. Mull It Over
- [AoC day page](https://adventofcode.com/2024/day/3)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/03_mull)

## Part one
The shopkeeper wants our help with the computer. The program wants to run the multiplication,
but computer memory is corrupted. Our goal is to run operations we can correctly identify
as multiplication and return the sum of the results.

The only correct variant of the operation is: `mul(X,Y)` where X and Y are three-digit numbers.

After all the troubles with the [previous day](02_reports.md) I've decided to use simple
regular expressions to extract the operations from the input and calculate the result.
While this approach may not be the most efficient, it works well for our input size.
For a more robust or scalable solution, writing a dedicated lexer could be an
interesting alternative to explore.


```go
type ParsedInput = []string

func ParseInput(lines []string) (ParsedInput, error) {
	defer Track("ParseInput")()

	return lines, nil
}

func PartOne(inp ParsedInput) int {
	defer Track("PartOne")()
    // \d -- is a digit and {1,3} -- means from 1 to 3 digits
	pattern := `mul\(\d{1,3},\d{1,3}\)`
	re := regexp.MustCompile(pattern)

	sum := 0

	for _, row := range inp {
		matches := re.FindAllString(row, -1)
		for _, match := range matches {
			var a, b int
			_, err := fmt.Sscanf(match, "mul(%d,%d)", &a, &b)
			if err != nil {
				panic(err)
			}
			sum += a * b
		}
	}
	return sum
}
```

## Part two
This part is almost the same as the first one. But now we need to account for
`do()` and `don't()` instructions:
- `do()` enables future `mul()` operations
- `don't()` disables future `mul()` operations

We start with the active state. I've decided to use a boolean flag for this and
check it before performing the multiplication if the match is `mul()` operation.

```go
func PartTwo(inp ParsedInput) int {
	defer Track("PartTwo")()
    // `|` indicates the OR operation for the pattern, so it's
    // `do()`, `don't()` or `mul(X,Y)` where X and Y are three-digit numbers
	pattern := `(do\(\)|don't\(\)|mul\(\d{1,3},\d{1,3}\))`
	re := regexp.MustCompile(pattern)

	sum := 0
	active := true
	var a, b int

	for _, row := range inp {
		matches := re.FindAllString(row, -1)
		if len(matches) == 0 {
			panic("no matches")
		}

		for _, match := range matches {
			switch match {
			case "do()":
				active = true
			case "don't()":
				active = false
			default:
				if !active {
					continue
				}
				if _, err := fmt.Sscanf(match, "mul(%d,%d)", &a, &b); err != nil {
					panic(fmt.Sprintf("parsing %s: %s", match, err))
				}
				sum += a * b
			}
		}

	}
	return sum
}
```

## Tags
- regular expressions
- parsing
