# Day 5. Print Queue
- [AoC day page](https://adventofcode.com/2024/day/5)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/05_queue)

The task is to sort the pages of the sleigh safety manual. The problem is that the pages
should be sorted in a very specific way. The rules look like this `47|53`. It means
that page 47 should be before page 53. Our input is set of these rules and stacks of pages.
Each stack is called an "update".

## Part one
In the first part we need to find the stacks which are already sorted and return the sum
of the middle pages of these stacks.

After reading the rules my first thought was to create a graph of the page relations and
use [topological sort](https://en.wikipedia.org/wiki/Topological_sorting)
to find the correct order, but the whole rule set contains a cycle (the A in DAG is broken).

But the page stacks do not contain cycles. So I've decided to go with the relation graph
still. The `Page` struct contains the page value and two maps of pages which
should be before and after the current page. And helper method to check the relation.

```go
type Page struct {
	Val    int
	Before map[int]struct{}
	After  map[int]struct{}
}

func NewPageOrdering(val int) Page {
	return Page{
		Val:    val,
		Before: make(map[int]struct{}),
		After:  make(map[int]struct{}),
	}
}

func (p *Page) AddBefore(val int) {
	p.Before[val] = struct{}{}
}

func (p *Page) AddAfter(val int) {
	p.After[val] = struct{}{}
}

func (p *Page) ShouldBeBefore(other Page) CompareResult {
	if _, ok := p.Before[other.Val]; ok {
		return Yes
	}
	if _, ok := p.After[other.Val]; ok {
		return No
	}
	return NotStrict
}
```

With pages in mind we can proceed and describe the `PagePrinter` struct which will
contain all pages rules (and updates just for parsing convenience).

The rule adding from input is straightforward: check the pages in the rule and add
the relation to each respective page struct.

```go
type PagePrinter struct {
	pages   [100]Page
	updates [][]int
}

func NewPagePrinter() PagePrinter {
	return PagePrinter{pages: [100]Page{}, updates: make([][]int, 0)}
}

func (pp *PagePrinter) AddRule(left, right int) {
	pp.ensurePage(left)
	pp.ensurePage(right)
	pp.pages[left].AddBefore(right)
	pp.pages[right].AddAfter(left)
}

func (pp *PagePrinter) ensurePage(val int) {
	if val < 10 || val > 99 {
		panic(fmt.Sprintf("invalid page value %d", val))
	}
	if pp.pages[val].Val == 0 {
		pp.pages[val] = NewPageOrdering(val)
	}
}

func (pp *PagePrinter) AddUpdate(update []int) {
	pp.updates = append(pp.updates, update)
}
```

So the parsing of the input is mostly about adding the rules to the `PagePrinter` struct:

```go
func parsePageRule(raw string) (int, int) {
	var left, right int

	_, err := fmt.Sscanf(raw, "%d|%d", &left, &right)
	if err != nil {
		panic(err)
	}
	return left, right
}

func parseUpdate(raw string) []int {
	split := strings.Split(raw, ",")
	update := make([]int, len(split))
	for i, s := range split {
		val, err := strconv.Atoi(s)
		if err != nil {
			panic(fmt.Sprintf("parsing %s: %s", s, err))
		}
		update[i] = val
	}

	return update
}

type ParsedInput = PagePrinter

func ParseInput(lines []string) (ParsedInput, error) {
	defer Track(time.Now(), "ParseInput")
	pp := NewPagePrinter()
	i := 0
	for {
		if i >= len(lines) {
			panic("end of input at rules parse")
		}

		left, right := parsePageRule(lines[i])
		pp.AddRule(left, right)
		i++

		if lines[i] == "" {
			break
		}
	}

	for i := i + 1; i < len(lines); i++ {
		update := parseUpdate(lines[i])
		pp.AddUpdate(update)
	}

	return pp, nil
}
```

The check of the update order is done by bubble-sort-like algorithm.
We check each page in the update against all previous pages in the update.
If we find a page which should not be before the current page we can stop the check:

```go
func (pp *PagePrinter) CheckUpdateOrdered(update []int) bool {
	for i := 1; i < len(update); i++ {
		cur, ok := pp.GetPage(update[i])
		if !ok {
			continue
		}
	BeforeLoop:
		for j := 0; j < i; j++ {
			prev, ok := pp.GetPage(update[j])
			if !ok {
				continue BeforeLoop
			}

			orderResult := prev.ShouldBeBefore(cur)

			switch orderResult {
			case Yes, NotStrict:
				continue BeforeLoop
			case No:
				return false
			default:
				panic(fmt.Sprintf("unexpected case %s", orderResult))
			}
		}

	}
	return true
}

func (pp *PagePrinter) GetPage(val int) (Page, bool) {
	page := pp.pages[val]
	if page.Val == 0 {
		return page, false
	}

	return page, true
}
```

After all preparations the main function is trivial:
```go
func PartOne(inp ParsedInput) int {
	defer Track(time.Now(), "PartOne")

	midSum := 0
	for _, update := range inp.updates {
		if !inp.CheckUpdateOrdered(update) {
			continue
		}
		midNum := update[len(update)/2]
		midSum += midNum
	}

	return midSum
}

```

## Part two
The second part in `what-a-twist` manner asks us to find unsorted updates, select all the sorted middle pages and sum them.

Proceeding with the bubble sort algorithm we can sort the update and check if it's
been already sorted. The bubble sort is not the most efficient algorithm, but for our
case with N < 25 it's good enough. Any other sorting algorithm may be used here.

The [quick select](https://en.wikipedia.org/wiki/Quickselect) or even 
[median of medians](https://en.wikipedia.org/wiki/Median_of_medians) may be more 
performant choices here.

```go
func (pp *PagePrinter) OrderUpdate(update []int) ([]int, bool) {
	updCopy := make([]int, len(update))
	copy(updCopy, update)
	update = updCopy
	alreadyOrdered := true
	for i := 1; i < len(update); i++ {
		cur, ok := pp.GetPage(update[i])
		if !ok {
			continue
		}
	BeforeLoop:
		for j := 0; j < i; j++ {
			prev, ok := pp.GetPage(update[j])
			if !ok {
				continue BeforeLoop
			}

			orderResult := prev.ShouldBeBefore(cur)

			switch orderResult {
			case Yes, NotStrict:
				continue BeforeLoop
			case No:
				alreadyOrdered = false
				update[i], update[j] = update[j], update[i]
			default:
				panic(fmt.Sprintf("unexpected case %s", orderResult))
			}
		}

	}
	return update, alreadyOrdered
}
```

Main function for the second part is almost the same as for the first part:

```go
func PartTwo(inp ParsedInput) int {
	defer Track(time.Now(), "PartTwo")
	midSum := 0
	for _, update := range inp.updates {
		orderedUpdate, alreadyOrdered := inp.OrderUpdate(update)
		if alreadyOrdered {
			continue
		}
		midNum := orderedUpdate[len(orderedUpdate)/2]
		midSum += midNum
	}

	return midSum
}
```

## Tags
- sorting
