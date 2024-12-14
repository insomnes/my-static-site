# Day 13. Claw Contraption
- [AoC day page](https://adventofcode.com/2024/day/13)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/13_claw)

While historians are spreading on a tropical island resort, we are chilling in the
resort's arcade. The claw machine awaits us, we need to win the prize.

## Part One
In the first part our task is to check if we can win the prize in 100 button presses.
Also we need to minimize the number of token spent. Each button press changes the claw
position by the fixed amount of steps to the right (`X`) and forward (`Y`).
Reading the task description reveals that `minimizing` condition
is the red herring. This is linear equation system with two variables and two equations.
Also the input doesn't contain any parallel lines, so we always have only one solution:

```go
const (
	MaxPushes = 100.0
	TokensA   = 3
	TokensB   = 1
)

type Answer struct {
	A, B  int
	Price int
	Valid bool
}

func NewAnswerFromFloats(a, b float64) Answer {
	if a < 0 || b < 0 {
		return Answer{}
	}

	if a > MaxPushes || b > MaxPushes {
		return Answer{}
	}
	if math.Mod(a, 1) != 0 || math.Mod(b, 1) != 0 {
		return Answer{}
	}
	ansA, ansB := int(a), int(b)
	price := ansA*TokensA + ansB*TokensB

	return Answer{A: ansA, B: ansB, Price: price, Valid: true}
}

type EquationSystem struct {
	Xa, Ya   float64
	Xb, Yb   float64
	Xpr, Ypr float64

	XaInt, YaInt   int
	XbInt, YbInt   int
	XprInt, YprInt int
}

// Equations system:
// Xa * a + Xb * b = Xpr
// Ya * a + Yb * b = Ypr
// !!!!!!!!!!!!!!!!!!!!!!!
// a = (Xpr - Xb * b) / Xa
// !!!!!!!!!!!!!!!!!!!!!!!
// Ya * ((Xpr - Xb * b) / Xa) + Yb * b = Ypr
// Ya * Xpr - Ya * Xb * b  + Yb * Xa * b = Ypr * Xa
// b * (Yb * Xa - Ya * Xb) = Ypr * Xa - Ya * Xpr
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// b = (Ypr * Xa - Ya * Xpr) / (Yb * Xa - Ya * Xb)
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
func (eq EquationSystem) Solve() Answer {
	if eq.Xa == eq.Xb && eq.Ya == eq.Yb {
		panic(fmt.Sprintf("Xa=%f, Xb=%f, Ya=%f, Yb=%f", eq.Xa, eq.Xb, eq.Ya, eq.Yb))
	}

	b := (eq.Ypr*eq.Xa - eq.Ya*eq.Xpr) / (eq.Yb*eq.Xa - eq.Ya*eq.Xb)
	a := (eq.Xpr - eq.Xb*b) / eq.Xa
	if a == 0.0 || b == 0.0 {
		panic(fmt.Sprintf("zero values: a=%f, b=%f", a, b))
	}
	return NewAnswerFromFloats(a, b)
}

type ParsedInput = []EquationSystem

...


func PartOne(inp ParsedInput) int {
	defer Track(time.Now(), "PartOne")
	total := 0

	for _, eq := range inp {
		answer := eq.Solve()
		if answer.Valid {
			total += answer.Price
		}
	}

	return total
}
```

## Part Two
Part two adds `10000000000000` to each coordinate of the prize position. So if you've
tried a tree search in the first part, you would consider new way to solve the task now.

Here I've used [Crammer's rule](https://en.wikipedia.org/wiki/Cramer%27s_rule)
with the matrix determinant to solve the system of equations.
We can also avoid [floats prescision problems](https://en.wikipedia.org/wiki/Floating-point_arithmetic)
(cause button presses are integers) by checking the remainder of the determinants' divisions:

```go
// The Cramer's rule to solve the system of equations
// (bonus: without floating point arithmetic)
// Xa * a + Xb * b = Xpr
// Ya * a + Yb * b = Ypr
//
// Matrix A:    Vec r:
// | Xa Xb |    | Xpr |
// | Ya Yb |    | Ypr |
//
// det(A) = Xa * Yb - Ya * Xb
// In our case det(A) == 0 -> unsolvable system
// det(A) != 0 -> may be solvable system, depending on if the roots are integer
// a = det(Aa) / det(A)
// b = det(Ab) / det(A)
func (eq EquationSystem) SolveWithDeterminants() Answer {
	detA := eq.DeterminantA()
	if detA == 0 {
		return Answer{}
	}

	detAa, detAb := eq.DeterminantAa(), eq.DeterminantAb()
	a, remA := divmod(detAa, detA)
	b, remB := divmod(detAb, detA)
	if remA != 0 || remB != 0 { // integer check
		return Answer{}
	}

	return NewAnswer(a, b)
}

func (eq EquationSystem) DeterminantA() int {
	return determinant(eq.XaInt, eq.XbInt, eq.YaInt, eq.YbInt)
}

// Aa -- change a column in matrix A with vector r
// | Xpr Xb |
// | Ypr Yb |
func (eq EquationSystem) DeterminantAa() int {
	return determinant(eq.XprInt, eq.XbInt, eq.YprInt, eq.YbInt)
}

// Ab -- change b column in matrix A with vector r
// | Xa Xpr |
// | Ya Ypr |
func (eq EquationSystem) DeterminantAb() int {
	return determinant(eq.XaInt, eq.XprInt, eq.YaInt, eq.YprInt)
}

// | a  b |
// | c  d |
func determinant(a, b, c, d int) int {
	return a*d - b*c
}

func divmod(a, b int) (int, int) {
	return a / b, a % b
}

func NewAnswer(a, b int) Answer {
	if a <= 0 || b <= 0 {
		return Answer{}
	}

	price := a*TokensA + b*TokensB
	return Answer{A: a, B: b, Price: price, Valid: true}
}


const clawPosExtra = 10000000000000

func PartTwo(inp ParsedInput) int {
	defer Track(time.Now(), "PartTwo")
	total := 0

	for _, eq := range inp {
		eq.XprInt, eq.YprInt = eq.XprInt+clawPosExtra, eq.YprInt+clawPosExtra
		answer := eq.SolveWithDeterminants()
		if answer.Valid {
			total += answer.Price
		}
	}

	return total
}
```

## Tags
- analytical solution
- system of equations
