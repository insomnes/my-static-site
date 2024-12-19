# Day 17. Chronospatial Computer
- [AoC day page](https://adventofcode.com/2024/day/17)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/17_computer)

The Chronospatial Computer is failing and we are here to help.

## Part One
In part one we just need to write a correct emulator for the computer and run the
provided program.
It has 3 registers (numbers are unlimited), is based on 3-bit numbers and has 8 instructions:

```go
type ChronoComputer struct {
	RegA uint64
	RegB uint64
	RegC uint64

	OutNumbers []uint64
}

func (c ChronoComputer) String() string {
	return fmt.Sprintf("CC{A: %d, B: %d, C: %d}", c.RegA, c.RegB, c.RegC)
}

func (c *ChronoComputer) Run(program Program) {
	insPtr := 0
	for insPtr < len(program) {
		opPointer := insPtr + 1
		// Halt case
		if opPointer >= len(program) {
			break
		}
		opcode := program[insPtr]
		instruction := SelectInstruction(opcode)

		opLiteral := program[opPointer]
		operator := NewOperator(opLiteral)

		insPtr = c.RunInstruction(instruction, operator, insPtr)
		if insPtr < 0 {
			panic(fmt.Sprintf("invalid instruction pointer: %d", insPtr))
		}
	}
}

func (c *ChronoComputer) RunInstruction(instruction Instruction, op Operator, insPtr int) int {
	newInsPtr := insPtr + 2

	switch instruction {
	case adv:
		c.adv(op)
	case bxl:
		c.bxl(op)
	case bst:
		c.bst(op)
	case jnz:
		newInsPtr = c.jumpLogic(op, insPtr)
	case bxc:
		c.bxc(op)
	case out:
		c.out(op)
	case bdv:
		c.bdv(op)
	case cdv:
		c.cdv(op)
	default:
		panic(fmt.Sprintf("unknown instruction: %d", instruction))
	}

	return newInsPtr
}
```

Nothing special here, just pedantic implementation of the operations:
```go
func (c *ChronoComputer) jumpLogic(op Operator, curInsPtr int) int {
	newInsPtr := c.jnz(op)
	if newInsPtr == -1 {
		return curInsPtr + 2
	}
	return newInsPtr
}

// A = A / 2 ** combo(op)
func (c *ChronoComputer) adv(op Operator) {
	c.RegA = c.divideA(op)
}

// B = A / 2 ** combo(op)
func (c *ChronoComputer) bdv(op Operator) {
	c.RegB = c.divideA(op)
}

// C = A / 2 ** combo(op)
func (c *ChronoComputer) cdv(op Operator) {
	c.RegC = c.divideA(op)
}

// B = B XOR op
func (c *ChronoComputer) bxl(op Operator) {
	c.RegB = c.RegB ^ op.ToNum()
}

// B = combo(op) % 8
func (c *ChronoComputer) bst(op Operator) {
	comboOperator := c.MakeCmbOp(op)
	res := comboOperator.ToNum() % 8
	c.RegB = res
}

// If A == 0 -> nothing (value is -1)
// If A != 0 -> jump to op (we just return the value)
func (c *ChronoComputer) jnz(op Operator) int {
	if c.RegA == 0 {
		return -1
	}
	if op.ToNum() >= math.MaxInt32 {
		panic(fmt.Sprintf("invalid jump: %d", op.ToNum()))
	}
	newInsPtr := int(op.ToNum())
	return newInsPtr
}

// B = B XOR C, op is ignored
func (c *ChronoComputer) bxc(op Operator) {
	c.RegB = c.RegB ^ c.RegC
}

// prints combo(op) % 8
func (c *ChronoComputer) out(op Operator) {
	comboOperator := c.MakeCmbOp(op)
	res := comboOperator.ToNum() % 8
	c.OutNumbers = append(c.OutNumbers, res)
}

// divideA helper
func (c *ChronoComputer) divideA(op Operator) uint64 {
	numerator := c.RegA
	comboOperator := c.MakeCmbOp(op)
	var denom uint64 = 1 << comboOperator.ToNum()
	return numerator / denom
}

func (c *ChronoComputer) MakeCmbOp(op Operator) ComboOperator {
	switch op {
	case 0, 1, 2, 3:
		return ComboOperator(op)
	case 4:
		return ComboOperator(c.RegA)
	case 5:
		return ComboOperator(c.RegB)
	case 6:
		return ComboOperator(c.RegC)
	default:
		panic(fmt.Sprintf("invalid operand: %d", op))
	}
}
```

## Part Two
Part two is whole another story. We need to detect which input (aka A register) will
produce a quine. Quine is a program that produces its own source code as output. So we
need to output the specific sequence of numbers. Instructions analysis shows that
output would operate on the last 3 bits of the number, and input would be cut with
division by 8 (also last 3 bits). Program will halt when we have 0 in the A register.

So we can start the number search backwards from 0 (this should be the last number in
all of this day inputs). So we start with 1 this will produce our 0. Each iteration
we want to "save" the number that will produce the current number, this will be done
by shifting the number 3 bits to the left. After that we can start the search for the
next number by running only 1 iteration (untill jump) of our program. I believe that
this solution should work in general for all of this day inputs:

```go
// We assume or know that:
//  0. A is the input register, for output we use B by default
//  1. To print 0 we need to have 8 in the register A, this is our start
//  2. Printing depends on 3 bit intervals (mod 8)
//  3. Each normal order iteration A value is divided by 8, so we
//  4. Multiplication of found value by 8 will give us the next starting value and save
//     our bit interval for printing
//  3. There is also no reason to check values from val to val * 8 after we found the
//     correct val. Cause the number is chunked in 3 bit intervals (see 2)
func ReverseBruteForce(program Program, getReg func(c *ChronoComputer) uint64) uint64 {
	var start uint64 = 1

	// Skip last '0' operator from the program
	for i := len(program) - 2; i >= 0; i-- {
		start *= 8
		num := program[i]
		found := false

		for a := start; a < start*8; a++ {
			c := ChronoComputer{RegA: a, RegB: 0, RegC: 0}
			// We should run only one iteration of our programn and check if the output
			// in register is what we expect, it is fast check and can lead to
			// false positives, which we check later
			c.RunTillJump(program)
			targetVal := getReg(&c)
			if targetVal%8 != num {
				continue
			}
			// If we found interesting value we should run the program to the end
			// and check if the full output is what we expect, program is small, so we
			// can run full calculation here
			c = ChronoComputer{RegA: a, RegB: 0, RegC: 0}
			c.Run(program)
			if !slices.Equal(c.OutNumbers, program[i:]) {
				continue
			}
			start = a
			found = true
			break

		}

		if !found {
			panic(fmt.Sprintf("not found: %v (%d) %d->%d", program[i:], num, start, start*8))
		}
	}

	return start
}
```

## Tags
- emulator
- quine
