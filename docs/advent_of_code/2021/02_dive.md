# Day 2. Dive
- [AoC day page](https://adventofcode.com/2021/day/)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2021/02_dive)

## Part one
Time to understand how the heck to pilot this submarine.

Submarine accepts commands in form of strings. 
Each command is a direction and a distance separated by space. We start at (0, 0).
We move only forward by x. And up and down are actually decrease or increase of y.

### Command parsing

Example commands:
```
forward 5
down 5
forward 8
up 3
down 8
forward 2
```

We just need to parse the commands properly:
```rust
pub enum Direction {
    Forward(i32),
    Down(i32),
    Up(i32),
}

impl FromStr for Direction {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let split = s.split(' ').collect::<Vec<&str>>();
        if split.len() != 2 {
            return Err("Wrong number of arguments".to_string());
        }
        let (dir, num) = (split[0], split[1]);
        let num = num.parse().expect("Failed to parse number");
        match dir {
            "forward" => Ok(Direction::Forward(num)),
            "down" => Ok(Direction::Down(num)),
            "up" => Ok(Direction::Up(num)),
            _ => Err("Wrong direction".to_string()),
        }
    }
}
```

### Command execution
After parsing we can execute the commands and calculate the final position.
For the sake of simplicity I parse all commands at once and then execute them.
But it's possible to parse and execute each command on the fly.

Solution:
```rust
pub fn part_one(input: Vec<Direction>) -> i32 {
    let mut x = 0;
    let mut y = 0;
    for cmd in input.iter() {
        match cmd {
            Direction::Forward(num) => x += num,
            Direction::Down(num) => y += num,
            Direction::Up(num) => {
                y -= num;
            }
        }
    }
    x * y
}
```


## Part two
After RTFM process we've learned that up and down are actually aim control for the submarine.

New aim related commands meaning:
```
- down X increases your aim by X units.
- up X decreases your aim by X units.
- forward X does two things:
  - It increases your horizontal position by X units.
  - It increases your depth by your aim multiplied by X.
```

It's not hard to adjust the previous solution to handle the new commands:
```rust
pub fn part_two(input: Vec<Direction>) -> i32 {
    let mut x = 0;
    let mut y = 0;
    let mut aim = 0;
    for cmd in input.iter() {
        match cmd {
            Direction::Forward(num) => {
                x += num;
                y += num * aim;
            }
            Direction::Down(num) => aim += num,
            Direction::Up(num) => aim -= num,
        }
    }
    x * y
}
```
