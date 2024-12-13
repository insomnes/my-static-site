# Day 11. Plutonian Pebbles
- [AoC day page](https://adventofcode.com/2024/day/11)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/11_pebbles)

We are researching ancient Plutonian civilization and while historians are busy with
the corridors, we are counting pebbles. The pebbles are pretty unusual, they change
each time you blink. We need to count the pebbles after a certain number of blinks.

## Part One
The blink rules are simple and we can code them in a straightforward way, add the 
cache to speed up future calls:

```go
// There would be a lot of blinks in part two for sure, so we prepare cache
// of the right size from the start
var blinkCache = make(map[uint64][]uint64, 4000)

func blink(n uint64) []uint64 {
    // If the number is 0, we return 1 as the result
	if n == 0 {
		return []uint64{1}
	}
    // If we have the result in the cache, we return it
	if val, ok := blinkCache[n]; ok {
		return val
	}
	s := strconv.FormatUint(n, 10)
    // If the number has odd digits, we multiply it by 2024
	// Slow but fine for this problem
	if len(s)%2 != 0 {
		result := n * 2024
		blinkCache[n] = []uint64{result}
		return []uint64{result}
	}

    // If the number has even digits, we split it in half by digits
	a, err := strconv.ParseUint(s[:len(s)/2], 10, 64)
	if err != nil {
		panic(err)
	}
	b, err := strconv.ParseUint(s[len(s)/2:], 10, 64)
	if err != nil {
		panic(err)
	}

	result := []uint64{a, b}
	blinkCache[n] = result

	return result
}
```

Part one has small number of blinks and can be solved in brute force way. But to
prepare for part two, we will use a more efficient way to count the pebbles.
Each blink is the separate operation. Each iteration we call `blink` on current number
but instead of storing the result in the list of all the the numbers, we store it in 
the counter map. So for each blink result we can increment the counter by the "parent"
number count. After the iteration we swap the maps and clear the temporary one to 
avoid re-allocating memory. The final result is the sum of all the counts in the final map:

```go
func SimulateBlinks(initNumbers []uint64, totalBlinks int) uint64 {
	counts := make(map[uint64]uint64, 4000)
	blinkCounts := make(map[uint64]uint64, 4000)
	for _, n := range initNumbers {
		counts[n]++
	}

	for range totalBlinks {
		for num, count := range counts {
			blinkResult := blink(num)
			for _, br := range blinkResult {
				blinkCounts[br] += count
			}
		}

		// To avoid re-allocating memory
		counts, blinkCounts = blinkCounts, counts
		clear(blinkCounts)
	}

	var total uint64 = 0
	for _, count := range counts {
		total += count
	}

	return total
}
```

Main function is just calling the `SimulateBlinks` with the initial numbers and the
blink count:
```go
func PartOne(inp ParsedInput) uint64 {
	defer Track(time.Now(), "PartOne")
	var total uint64 = 0

	total = SimulateBlinks(inp, partOneBlinks)

	return total
}
```

## Part Two
Part two is literally the same as part one, but with the bigger number of blinks, so 
brute force solution would be too slow:
```go
func PartTwo(inp ParsedInput) uint64 {
	defer Track(time.Now(), "PartTwo")
	var total uint64 = 0

	total = SimulateBlinks(inp, partTwoBlinks)

	return total
}

## Tags
- counter
- memoization
