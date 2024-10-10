---
date:
  created: 2024-10-09
  updated: 2024-10-10
---

# Git bisect
Recently I've learned about the `git bisect` [command](https://git-scm.com/docs/git-bisect)
and I think it's a very powerful and useful tool to find bugs in your codebase. It allows you
to find the commit that introduced a bug by performing a binary search and even
automating the process of checking out commits and testing them.

<!-- more -->

## Basics
The `git bisect` command is a binary search tool that helps you find the commit
that introduced a bug. You define "good" and "bad" commits. By good, we mean a commit
where the bug is not present. By bad, we mean a commit where the bug is present.
Git checks out commits in the middle of the range and you test them. Based on the
result, you tell git if the commit is good or bad. Git then checks out the next commit
in the middle of the remaining range and you repeat the process until you find the
commit that introduced the bug.

## Setup
Let's clone an example repository:
```bash
git clone https://github.com/insomnes/gitbisect-example.git
cd gitbisect-example
```
We also have a little script that we are running from time to time.
It's called `rm_dups.py`. We would need to add it to repo root.
```python
import listops as lo


if __name__ == '__main__':
    lst = [1, 1, 2, 2, 22, 22, 3, 4, 5]
    print(f"Removing duplicates from list: {lst}")
    no_dups = lo.remove_duplicates(lst)
    print(f"List without duplicates: {no_dups}")
```

## Detecting the bug
After a while, we have returned to our project and found out that the script
is not working as expected. We have noticed that removing duplicates is no longer
preserving the order of the elements!


```bash
python rm_dups.py
```
This will print:
```
Removing duplicates from list: [1, 1, 2, 2, 22, 22, 3, 4, 5]
List without duplicates: [1, 2, 3, 4, 5, 22]
```
But you can remember that it was working correctly before! Let's use `git bisect` to find the commit that introduced the bug.

## Manual bisect
Start the bisect process:
```bash
git bisect start
```

### Marking the current commit as bad
First, we need to mark the current commit as bad:
```bash
git bisect bad
```

### Finding the first good commit
You totally remember that the script was working correctly in one of the first commits.
Let's find when `remove_duplicates` function was added:
```bash
git log --reverse --oneline | head -n 3
```
This will print:
```
dadba62 Initial commit
0a3f09b Add remove_duplicates
6d0a279 Extend with adding elements
```

Let's remember mark the commit hash `0a3f09b` as good:
```bash
git bisect good 0a3f09b
```

### Finding the bad commit
This will start the bisect process and checkout the commit in the middle of the range.
Let's run the script and check if the bug is present:
```bash
python rm_dups.py
```
Still the bug is present:
```
Removing duplicates from list: [1, 1, 2, 2, 22, 22, 3, 4, 5]
List without duplicates: [1, 2, 3, 4, 5, 22]
```

Mark the commit as bad:
```bash
git bisect bad
```

This will checkout the next commit in the middle of the remaining range.
let's run the script again:
```
Removing duplicates from list: [1, 1, 2, 2, 22, 22, 3, 4, 5]
List without duplicates: [1, 2, 22, 3, 4, 5]
```
A-ha! The bug is not present in this commit. Let's mark it as good:

```bash
git bisect good
```
Hm! Possibly we have found the commit that introduced the bug:
```
Bisecting: 0 revisions left to test after this (roughly 1 step)
[0f4af123fd8ccdfbeb7eb5b20fcf81d72b985ffb] Speed up remove duplicates
```
Let's find out by running the script:
```
Removing duplicates from list: [1, 1, 2, 2, 22, 22, 3, 4, 5]
List without duplicates: [1, 2, 3, 4, 5, 22]
```
Yes! The bug is present in this commit. Let's mark it as bad:
```bash
git bisect bad
```
This will lead us to the next commit, and we can see that the bug is not present there:
```
Removing duplicates from list: [1, 1, 2, 2, 22, 22, 3, 4, 5]
List without duplicates: [1, 2, 22, 3, 4, 5]
```
Let's mark it as good then:
```bash
git bisect good
```
Ta-da! We have certanly found the commit that introduced the bug:
```
0f4af123fd8ccdfbeb7eb5b20fcf81d72b985ffb is the first bad commit
commit 0f4af123fd8ccdfbeb7eb5b20fcf81d72b985ffb
...

    Speed up remove duplicates

 listops.py | 11 +----------
 1 file changed, 1 insertion(+), 10 deletions(-)
```

Let's see what has changed in this commit:
```bash
git show 0f4af123fd8ccdfbeb7eb5b20fcf81d72b985ffb
```

Yeah it's clear now. New implementation of `remove_duplicates` function is not preserving the order of the elements:
```python
def remove_duplicates(lst: list) -> list:
    return list(set(lst))
```
Instead of the previous implementation:
```python
def remove_duplicates(lst: list) -> list:
    present = set()
    result = []
    for item in lst:
        if item in present:
            continue
        present.add(item)
        result.append(item)

    return result
```

You can reset the bisect process by running:
```bash
git bisect reset
```

## Automating the process
That's handy but also quite time-consuming. You can automate the process by providing a script that will check if the bug is present in the current commit.

But we will need to change our script a bit. We will exit with code 0 if the bug is not present and with code 1 if the bug is present:
```python
import listops as lo


if __name__ == '__main__':
    lst = [1, 1, 2, 2, 22, 22, 3, 4, 5]
    print(f"Removing duplicates from list: {lst}")
    no_dups = lo.remove_duplicates(lst)
    print(f"List without duplicates: {no_dups}")
    if no_dups == [1, 2, 22, 3, 4, 5]:
        exit(0)
    else:
        exit(1)
```
Now we can start the bisect process and provide the script:
```bash
# Start the bisect process and mark the HEAD as bad and 0a3f09b as good
git bisect start HEAD 0a3f09b --
# Tell git to run the script and check if the bug is present
git bisect run python rm_dups.py
```
This will lead us to the same commit that introduced the bug, but we can just relax while git will do all the work:
```
running 'python' 'rm_dups.py'
Removing duplicates from list: [1, 1, 2, 2, 22, 22, 3, 4, 5]
List without duplicates: [1, 2, 3, 4, 5, 22]
Bisecting: 2 revisions left to test after this (roughly 1 step)
[06380b67db56c002d2bdb9d18df60e9c18347dc7] Extend with adding elements and no dups combined
...
0f4af123fd8ccdfbeb7eb5b20fcf81d72b985ffb is the first bad commit
...
    Speed up remove duplicates

 listops.py | 11 +----------
 1 file changed, 1 insertion(+), 10 deletions(-)
bisect found first bad commit
```

That's it! You can now fix the bug and continue with your work.

## Skip untestable parts
Let's say we have another broken script and we don't want to search at which commit
the specific function was introduced to mark it as good. `git bisect` can help here too!
First of all put new script `add_elements_wo_dups.py` file to repository dir root:
```python
try:
    from listops import add_elements_wo_dups
except ImportError:
    # Exit code 125 notifies bisect process to skip this commit as in `git bisect skip`
    exit(125)


if __name__ == '__main__':
    lst1 = [1, 1, 22, 22, 3]
    lst2 = [5, 5, 4, 4]
    print(f"Adding with removing duplicates: {lst1} + {lst2}")
    sum = add_elements_wo_dups(lst1, lst2)
    print(f"Sum without duplicates: {sum}")
    if sum == [1, 22, 3, 5, 4]:
        exit(0)
    else:
        exit(1)
```
As mentioned the key here is to exit with code `125` when commit should be skipped.
Without this addition `git bisect` will point to the wrong commit as bad (import error 
leads to exit code `1`).

Let's start our bisecting process again (the `git log ...` part extract first commit 
from the repo):
```bash
git bisect start HEAD $(git log --reverse --oneline | head -n 1 | cut -d ' ' -f1)
git bisect run python add_elements_wo_dups.py
```

This will lead to famialiar output of searching for the culprit:
```
Bisecting: 5 revisions left to test after this (roughly 3 steps)
[0f4af123fd8ccdfbeb7eb5b20fcf81d72b985ffb] Speed up remove duplicates
running 'python' 'add_elements_wo_dups.py'
Adding with removing duplicates: [1, 1, 22, 22, 3] + [5, 5, 4, 4]
Sum without duplicates: [1, 3, 4, 5, 22]
Bisecting: 2 revisions left to test after this (roughly 1 step)
[6d0a279840995bfc9b54f47649fa2d7b318e70b6] Extend with adding elements
running 'python' 'add_elements_wo_dups.py'
Bisecting: 1 revision left to test after this (roughly 1 step)
[06380b67db56c002d2bdb9d18df60e9c18347dc7] Extend with adding elements and no dups combined
running 'python' 'add_elements_wo_dups.py'
...
Bisecting: 0 revisions left to test after this (roughly 0 steps)
[1ee708cc82e69a4393583f960e70eca3ac7eba4d] Add single element operation add
running 'python' 'add_elements_wo_dups.py'
Adding with removing duplicates: [1, 1, 22, 22, 3] + [5, 5, 4, 4]
Sum without duplicates: [1, 22, 3, 5, 4]
0f4af123fd8ccdfbeb7eb5b20fcf81d72b985ffb is the first bad commit
commit 0f4af123fd8ccdfbeb7eb5b20fcf81d72b985ffb
...
    Speed up remove duplicates

 listops.py | 11 +----------
 1 file changed, 1 insertion(+), 10 deletions(-)
bisect found first bad commit
```

## Automatically bisecting with temporary modifications
But what if we have some new modifications in other branch that we need to detect the bug.
Let's switch to the `add-tests` branch:
```bash
git switch add-tests
```
In this branch we have added very simple tests in `test_listops.py`:
```bash
python test_listops.py
```

Yeah! The tests are failing:
```
Running tests
Running remove_duplicates tests
Traceback (most recent call last):
...
    assert lo.remove_duplicates([1, 1, 2, 2, 22, 22, 3, 4, 5]) == [1, 2, 22, 3, 4, 5]
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
AssertionError
```

We can bisect with the power of tests now! 
```bash
git bisect start HEAD 0a3f09b --
git bisect run python test_listops.py

```

Hmm. Something went wrong, we found different commit this time:
```
python: can't open file '.../test_listops.py': [Errno 2] No such file or directory
6d0a279840995bfc9b54f47649fa2d7b318e70b6 is the first bad commit
commit 6d0a279840995bfc9b54f47649fa2d7b318e70b6
...
    Extend with adding elements

 listops.py | 4 ++++
 1 file changed, 4 insertions(+)
bisect found first bad commit
```

Oh no! Bisecting process will checkout to the commit to find the bug,
but we don't have the tests in this commit. So each time we need to merge the `add-tests` 
branch to the current branch and run the tests again.

We should find our tests commit hash:
```bash
git log --oneline -1
```
This will print:
```
138e2a5 (HEAD -> add-tests) Add simple tests
```

Let's add a little helper script `test.sh`:
```bash
#!/bin/bash
# Add our test to the working tree
git cherry-pick --no-commit --no-ff 138e2a5
# Run the tests
python test_listops.py
# Capture the exit status
status=$?
# Reset the working tree
git reset --hard
# Exit with the captured status
exit $status
```

Now we can run automated bisect again:
```bash
git bisect start HEAD 0a3f09b --
git bisect run ./test.sh
```

This will lead us to the same commit as before:
```
Bisecting: 5 revisions left to test after this (roughly 3 steps)
[9c0782d5943c778bc36c76653d788734bf2b21fd] Add remove elements
running './test.sh'
Running tests
Running remove_duplicates tests
Traceback (most recent call last):
...
Bisecting: 0 revisions left to test after this (roughly 0 steps)
[1ee708cc82e69a4393583f960e70eca3ac7eba4d] Add single element operation add
running './test.sh'
Running tests
Running remove_duplicates tests
All tests passed
HEAD is now at 1ee708c Add single element operation add
0f4af123fd8ccdfbeb7eb5b20fcf81d72b985ffb is the first bad commit
commit 0f4af123fd8ccdfbeb7eb5b20fcf81d72b985ffb
...
    Speed up remove duplicates

 listops.py | 11 +----------
 1 file changed, 1 insertion(+), 10 deletions(-)
bisect found first bad commit
```

Don't forget to reset the bisect process:
```bash
git bisect reset
```

## Conclusion
This command is not your day-to-day tool, but it's very useful for finding some odd
bugs that you can't track down. It's also a great way to learn how git works under the hood.
I hope you will find it as useful as I did. Happy bisecting!
