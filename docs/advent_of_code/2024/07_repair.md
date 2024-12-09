# Day 7. Bridge Repair
- [AoC day page](https://adventofcode.com/2024/day/7)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/07_repair)

The strange parade continues and now we need to help engineers with bridge repair.
They have equations but elephants stole the operators from them. We need to find
how to add `+` and `*` to the equation to get the desired result.

Operations are resolved from left to right and there is no operator precedence.
For example:
- `190: 19 10` is `19 * 10 = 190`
- `3267: 81 40 27` is `81 + 40 * 27 = 3267` or `81 * 40 + 27 = 3267`
- `292: 11 6 16 20` is `11 + 6 * 16 + 20 = 292`

## Part one
In the first part, we need to find the solvable equations and sum the results.

We are again at the state space which is the tree of the numbers and nodes
are differ by the used operation, for example:
```
             _____11_____
            /            \
         *6/              \+6
         66                17
      *16/ \+16        *16/ \+16
        /   \            /   \
    -1056-  82         272    33
        *20/ \+20   *20/ \+20  .....
          /   \       /   \
      -1640- -102- -5440- +292+


```
We can traverse this tree in a depth-first manner and cut the branch early if we know
that the result is not reachable with the current operation. But there is even more
efficient way to do this. We can start from the end of the equation and try to
apply the operation backward. For example, if we know that we are looking for the
multiplication we can stop if the result is not divisible by the current number.

Backward tree:
```
      292_
 div20/   \-20             
    ---    272
        -16/ \div16
          /   \
       256     17
    div6/ \-6  / \-6
     ---   \  /   \
           ...   +11+
```

As we can see it takes less steps through the tree to find the solution this way.

So we would need to code the state for our state space and the ability to apply
the operation backward. Then we can prepare the next states based on the current state.
If we find the solution we can stop the search and return the result.

```go
type Equation struct {
	Result  uint64
	Numbers []uint64
}

type State struct {
	Current   uint64
	NextI     int
	Operation Operation
}

type Operation uint8

const (
	_ Operation = iota
	OpAdd
	OpMul
)

func (o Operation) ApplyBackward(result, next uint64) (uint64, bool) {
	// Based on operation we can cut our backward search early
	// For example, if we know that we are looking for a multiplication
	// we can stop if the result is not divisible by the next number
	switch o {
	case OpAdd:
		return result - next, true
	case OpMul:
		return result / next, result%next == 0
	default:
		panic(fmt.Sprintf("unknown operation: %d", o))
	}
}

func prepareNextStates(current uint64, nextI int, ops []Operation) []State {
	states := make([]State, len(ops))
	for i, o := range ops {
		states[i] = State{
			Current:   current,
			NextI:     nextI,
			Operation: o,
		}
	}
	return states
}

// Operation order is important for our LIFO queue, cause we want to check
// multiplication first to cut the whole branch early
var PartOneOperations = []Operation{OpAdd, OpMul}

func ProcessState(s State, next uint64, ops []Operation) ([]State, bool) {
	if s.NextI == 0 {
		if s.Current == next {
			return nil, true
		}
		return nil, false
	}
	opResult, ok := s.Operation.ApplyBackward(s.Current, next)
	if !ok {
		return nil, false
	}
	return prepareNextStates(opResult, s.NextI-1, ops), false
}
```

To find out if the equation is solvable we go through all possible operations
with branch cutting and return true if we find the solution.

```go
func IsSolvable(eq Equation, operations []Operation) bool {
	lastI := len(eq.Numbers) - 1
	queue := prepareNextStates(eq.Result, lastI, operations)

	for len(queue) > 0 {
		s := queue[len(queue)-1]
		queue = queue[:len(queue)-1]

		newStates, solved := ProcessState(s, eq.Numbers[s.NextI], operations)
		if solved {
			return true
		}
		queue = append(queue, newStates...)
	}

	return false
}

func PartOne(inp ParsedInput) uint64 {
	defer Track(time.Now(), "PartOne")

	var res uint64 = 0
	for _, eq := range inp {
		if IsSolvable(eq, PartOneOperations) {
			res += eq.Result
		}
	}

	return res
}
```

## Part two
Part two just adds the concatenation operation to the list of operations.
Concatenation joins numbers as strings. For example:
- `123` concatenated with `45` becomes `12345`.
- `56` concatenated with `7` becomes `567`.

Expanding our previous code to support this operation is straightforward. We just need
to add the operation to the list and implement the backward application.

```go
const (
	_ Operation = iota
	OpAdd
	OpMul
	OpConcat
)

func (o Operation) ApplyBackward(result, next uint64) (uint64, bool) {
	switch o {
	case OpAdd:
		return result - next, true
	case OpMul:
		return result / next, result%next == 0
	case OpConcat:
		return UnConcat(result, next)
	default:
		panic(fmt.Sprintf("unknown operation: %d", o))
	}
}

func UnConcat(a, b uint64) (uint64, bool) {
	for b > 0 {
		if a%10 != b%10 {
			return 0, false
		}
		a /= 10
		b /= 10
	}

	return a, true
}
//
// ...
//

// Same logic as in PartOne, but with concatenation operation first
var PartTwoOperations = []Operation{OpAdd, OpMul, OpConcat}

func PartTwo(inp ParsedInput) uint64 {
	defer Track(time.Now(), "PartTwo")

	var res uint64 = 0
	for _, eq := range inp {
		if IsSolvable(eq, PartTwoOperations) {
			res += eq.Result
		}
	}

	return res
}
```

## Tags
- state space
- DFS
