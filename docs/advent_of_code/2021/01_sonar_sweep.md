# Day 1. Sonar sweep
- [Task page](https://adventofcode.com/2021/day/1)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2021/01_sonar)

## Part one
Submarine has sonar and can measure depths.
Each of the measurements is present as positive integer on a new line.

This part is really simple and requires us to calculate how many measuremnts are larger than previous measurement.

Here we iter over pairs of elements and compare the values.

```rust
pub fn part_one(input: Vec<i32>) -> i32 {
    let mut increased = 0;
    input.windows(2).for_each(|pair| {
        if pair[1] > pair[0] {
            increased += 1;
        }
    });

    increased
}
```

## Part two
This part is a bit trickier. Our goal now is to count the number of times the
sum of measurements in this sliding window increases from the previous sum.

We iterate over windows of size 3 (iteration is kickstarted manually to get first triplet)
and compare the sum of the current window with the sum of the previous window.

```rust
pub fn part_two(input: Vec<i32>) -> i32 {
    let mut increased = 0;
    let mut triplet_iter = input.windows(3);
    let mut prev = triplet_iter.next().expect("Empty iter");
    for next in triplet_iter {
        if next.iter().sum::<i32>() - prev.iter().sum::<i32>() > 0 {
            increased += 1;
        }
        prev = next;
    }
    increased
}
```

