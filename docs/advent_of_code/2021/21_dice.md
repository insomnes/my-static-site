# Day 21. Dirac Dice
- [AoC day page](https://adventofcode.com/2021/day/21)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2021/21_dice)

## Game rules
It's a good time to kill time playing Dirac Dice against the submarine computer.

The game has two players, each with a pawn on a round board with 10 spaces,
numbered 1 to 10. Players take turns rolling a die three times and adding up the numbers.
They move their pawn that many spaces, going around the board if needed. 
The player's score goes up by the number of the space they stop on.

## Part one
In this part we have deterministic dice. This die always rolls 1 first, then 2, then 3,
and so on up to 100, after which it starts over at 1 again.
The game ends when one player’s score reaches 1000.

Our goal is to detemine the losing player's score and the overall dice roll count.
After that we need to calculate the product of the two numbers.

### Find reapeting pattern
The dice rolls are deterministic, so we can find the pattern:

```rust
// This is not the optimal solution for cycle detection, but it's good enough
fn find_repeating_postions(input: ParsedInput) -> (Vec<usize>, Vec<usize>) {
    let mut p1_pos = input[0];
    let mut p1_all = Vec::new();
    let mut p1_found = 0;

    let mut p2_pos = input[1];
    let mut p2_all = Vec::new();
    let mut p2_found = 0;

    for n in 1..100 {
        if p1_found > 0 && p2_found > 0 {
            break;
        };
        // Player 1
        if n % 2 != 0 {
            if p1_found > 0 {
                continue;
            }
            p1_pos = move_player(p1_pos, n);
            p1_all.push(p1_pos);
            if check_player_position(&p1_all) {
                p1_found = n / 2;
                // We need to store only the first half of the repeating pattern
                p1_all = p1_all[..p1_all.len() / 2].to_vec();
                println!("{} ({}) P1: {:?}", n, p1_found, p1_all);
            }
            continue;
        };

        // Player 2
        if p2_found > 0 {
            continue;
        }
        p2_pos = move_player(p2_pos, n);
        p2_all.push(p2_pos);
        if check_player_position(&p2_all) {
            p2_found = n / 2;
            p2_all = p2_all[..p2_all.len() / 2].to_vec();
            println!("{} ({}) P2: {:?}", n, p2_found, p2_all);
        }
    }

    (p1_all, p2_all)
}

fn check_player_position(all: &[usize]) -> bool {
    if all.len() < 2 || all.len() % 2 != 0 {
        return false;
    }
    all[..all.len() / 2] == all[all.len() / 2..]
}

fn move_player(pos: usize, roll: usize) -> usize {
    let new_pos = pos + calculate_roll_sum(roll);
    if new_pos % 10 == 0 {
        return 10;
    }
    new_pos % 10
}

fn calculate_roll_sum(r_num: usize) -> usize {
    let a = fix_100_overflow(3 * (r_num - 1)) + 1;
    let b = fix_100_overflow(3 * (r_num - 1) + 1) + 1;
    let c = fix_100_overflow(3 * (r_num - 1) + 2) + 1;

    a + b + c
}

fn fix_100_overflow(num: usize) -> usize {
    if num < 100 {
        return num;
    }
    num % 100
}
```

### Calculating player's win round
After we've found the repeating pattern we can calculate the round
when each of the player wins the game.
```rust
fn find_player_win_round(all_pos: &[usize]) -> usize {
    let p_sum: usize = all_pos.iter().sum();
    // Full cycles of the repeating pattern
    let p_fulls = 1000 / p_sum * all_pos.len();
    // Should we simulate last N rounds?
    let p_remainder = 1000 % p_sum;
    if p_remainder == 0 {
        return p_fulls;
    }

    let mut sum = 0;
    let mut rounds = None;
    for (i, score) in all_pos.iter().enumerate() {
        sum += score;
        if sum >= p_remainder {
            rounds = Some(i + 1);
            break;
        }
    }
    if let Some(rounds) = rounds {
        p_fulls + rounds
    } else {
        panic!("No solution found");
    }
}
```

### Final solution
The final solution is pretty straightforward after all the preparations:

```rust
// A bit verbose for the sake of simplicity
pub fn part_one(input: ParsedInput) -> usize {
    let (p1, p2) = find_repeating_postions(input);
    let mut p1_rounds = find_player_win_round(&p1);
    let mut p2_rounds = find_player_win_round(&p2);
    println!("P1: {} P2: {}", p1_rounds, p2_rounds);
    if p1_rounds < p2_rounds {
        // 3 rolls per round, 2 players, second player didn't get a final role so -3
        let total_rolls = p1_rounds * 3 * 2 - 3;
        p2_rounds = p1_rounds - 1;
        let mut p2_score = p2.iter().sum::<usize>() * (p2_rounds / p2.len());
        if p2_rounds % p2.len() != 0 {
            p2_score += p2[..p2_rounds % p2.len()].iter().sum::<usize>();
        }
        println!("P2 score: {}, Total rolls: {}", p2_score, total_rolls);

        return total_rolls * p2_score;
    }

    let total_rolls = p2_rounds * 3 * 2;
    p1_rounds = p2_rounds;
    let mut p1_score = p1.iter().sum::<usize>() * (p1_rounds / p1.len());
    if p1_rounds % p1.len() != 0 {
        p1_score += p1[..p1_rounds % p1.len()].iter().sum::<usize>();
    }
    println!("P1 score: {}, Total rolls: {}", p1_score, total_rolls);
    total_rolls * p1_score
}
```

## Part two
This part is whole another story. The dice is not deterministic anymore. Warm up is over.
We are now playing with The Dirac Dice. The die has 3 sides.
When this dice is rolled, the universe splits into three versions—one for each
possible outcome (1, 2, or 3). The game is played the same as before,
but it ends when either player reaches a score of 21 instead of 1000.

We need to find the player that wins in more universes and exact number of win-universes
for the winning player.

### Define the state space
To determine the game state we need to know these board parameters:
- Current player position
- Other player position
- Current player score
- Other player score

We have 27 different universes after each turn. That grows exponentially.
One way to cut the number of universes is to store the roll sums and frequencies.
```rust
const POSSIBLE_ROLLS: [usize; 7] = [3, 4, 5, 6, 7, 8, 9];
// Simplify indexing of the roll sums
const ROLL_FREQ: [usize; 10] = [0, 0, 0, 1, 3, 6, 7, 6, 3, 1];
```
So we can work with 7 possible universes instead of 27 and use the frequencies
when we need to determine the number of corresponding universes.

### Recursion with memoization
We can use recursion to calculate different game states outcomes.

```rust
pub fn part_two(input: ParsedInput) -> usize {
    let (p1, p2) = (input[0], input[1]);

    let mut cache = HashMap::new();
    let (p1_wins, p2_wins) = count_dirac_wins(p1, p2, 0, 0, &mut cache);
    let max_wins = p1_wins.max(p2_wins);
    println!("P1: {}, P2: {}, Max: {}", p1_wins, p2_wins, max_wins);
    max_wins
}

fn count_dirac_wins(
    cur: usize,
    other: usize,
    cur_score: usize,
    other_score: usize,
    cache: &mut HashMap<(usize, usize, usize, usize), (usize, usize)>,
) -> (usize, usize) {
    // We can save a lot by memoization since we have a lot of repeated states
    if let Some(&wins) = cache.get(&(cur, other, cur_score, other_score)) {
        return wins;
    }
    if cur_score >= WIN_POS_2 {
        return (1, 0);
    }
    if other_score >= WIN_POS_2 {
        return (0, 1);
    }
    let mut cur_wins = 0;
    let mut other_wins = 0;

    for roll in POSSIBLE_ROLLS {
        let new_pos = (cur + roll - 1) % 10 + 1;
        let new_score = cur_score + new_pos;
        // The tricky part here is to switch the players (this allows less calculations)
        let (new_other_wins, new_cur_wins) =
            count_dirac_wins(other, new_pos, other_score, new_score, cache);
        // Frequency of the roll trick usage
        cur_wins += new_cur_wins * ROLL_FREQ[roll];
        other_wins += new_other_wins * ROLL_FREQ[roll];
    }
    cache.insert((cur, other, cur_score, other_score), (cur_wins, other_wins));
    (cur_wins, other_wins)
}
```
