# Day 1. Historian Hysteria
- [AoC day page](https://adventofcode.com/2024/day/1)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/01_history)

## Part one
We need to find the difference between sorted values of two lists with Location IDs (integers).
And sum all the differences.
The tricky part is that the lists are not sorted. The most straightforward way to solve
this is to sort the lists and then calculate the difference between the values.

```go
type ParsedInput = [][2]int

func PartOne(inp ParsedInput) int {
	inpLen := len(inp)
	lList := make([]int, 0, inpLen)
	rList := make([]int, 0, inpLen)

	for _, p := range inp {
		left, right := p[0], p[1]
		lList = append(lList, left)
		rList = append(rList, right)
	}

	slices.Sort(lList)
	slices.Sort(rList)

	res := 0

	for i, n := range lList {
		res += abs(n - rList[i])
	}

	return res
}
```

## Part two
Our new goal is to understand how many times each Location ID from the left list appears 
in the right list and sum it up. 

Here I wanted to run only one loop through the pairs, so we would count numbers on the fly.
After increasing numbers count for each of the lists, we can adjust the result by
add current count of the left number in the right list and the current count of 
the right number in the left list. If the numbers are the same, we need to subtract one of them
from the result.


```go
func PartTwo(inp ParsedInput) int {

	inpLen := len(inp)
	lList := make([]int, 0, inpLen)
	lCount := make(map[int]int, inpLen)

	rList := make([]int, 0, inpLen)
	rCount := make(map[int]int, inpLen)

	res := 0

	for _, p := range inp {
		left, right := p[0], p[1]

		lList = append(lList, left)
		lCount[left]++

		rList = append(rList, right)
		rCount[right]++

		res += left * rCount[left]

		res += right * lCount[right]
		if left == right {
			res -= left
		}

	}

	return res
}
```
