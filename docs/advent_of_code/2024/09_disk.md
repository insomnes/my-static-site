# Day 9. Disk Fragmenter
- [AoC day page](https://adventofcode.com/2024/day/9)
- [Full solution source code](https://github.com/insomnes/aoc/tree/main/2024/09_disk)

We are underwater in a convenientrly happened submarine and need to help the amphipod
to move files on the disk. The input is the number sequence describing the disk state.

```
State:  12345
FileID: 0.1.2

File ID: 0 -> 1 block
  Empty -> 2 blocks
File ID: 1 -> 3 blocks
  Empty -> 4 blocks
File ID: 2 -> 5 blocks

Final:
  0..111....2222
```

## Part One
In the first part, we need to fill the empty spaces present on disk by moving current
rightmost file block to the leftmost empty space. After that we need to calculate the
checksum of the disk state. The checksum is the product of the File ID of the disk block
and the block index (empty spaces are skipped, but still contribute to the index).

So, how do we code the disk? We can use the following structure:

```go
type FileID int

const emptyFID FileID = -1

type DiskInfo struct {
	Blocks []FileID
	// There could be only 1-9 and 0 is here to not drown in OBOE
	EmptyIndciesBySize [10][]int
}

type ParsedInput = DiskInfo

...

// Disk is represented by contiguous slice of "blocks"
// where each block is a FileID value
// -1 is a special value of FileID for an empty block
// so 12345:
// i: 0    1  2   3 4 5   6  7  8  9   10 11 12 13 14
//
//	  0   -1 -1   1 1 1  -1 -1 -1 -1    2  2  2  2  2
//
// EmptyCatalog contains indices pointing to start of the empty
// blocks of a certain size
// so for the example above it would be:
// 2: [1]
// 4: [6]
type Disk struct {
	Blocks       []FileID
	EmptyCatalog [10][]int
}
```

With the "array of blocks" representation, we can easily move the blocks around and
use two pointers to track the leftmost empty block and the rightmost file block:

```go
func (d *Disk) Compactify() {
	li, ri := 0, len(d.Blocks)-1
	// Move left pointer and right pointer towards each other until they meet
	for li < ri {
		// Seek the first empty block from the left
		if d.Blocks[li] != emptyFID {
			li++
			continue
		}
		// Seek the first non-empty block from the right
		if d.Blocks[ri] == emptyFID {
			ri--
			continue
		}
		// Swap the blocks, when both pointers are in the right place
		d.Blocks[li], d.Blocks[ri] = d.Blocks[ri], emptyFID
		li++
		ri--
	}
}
```

The checksum calculation is straightforward and the whole PartOne solution is just
`Compactify` and `Checksum` calls.

```go
func (d *Disk) Checksum() uint64 {
	var cs uint64 = 0

	for i, fileID := range d.Blocks {
		if fileID == emptyFID {
			continue
		}
		cs += uint64(i) * uint64(fileID)
	}

	return cs
}

func PartOne(inp ParsedInput) uint64 {
	defer Track(time.Now(), "PartOne")

    // Clone the input because we need to modify it
	blocks := slices.Clone(inp.Blocks)
	disk := Disk{Blocks: blocks}
	disk.Compactify()

	return disk.Checksum()
}
```

## Part Two

This part looks more like a disk defragmentation task. We need to find the left most
fitting empty space for each file (all of the blocks) and move them there. That's why 
we have empty spaces catalog in the `Disk` structure. If there is no fitting space,
we skip the file.

This looks simple, but the implementation is really tricky, and I've met a lot of
edge cases during the development. Provided test cases are not enough to cover all
the possible scenarios.

I think we can solve the problem via doubly linked list of disk "segments",
but I've decided to stick with the array representation and right pointer plus
search for the leftmost empty space via sized buckets.

The defragmentation algorithm is as follows:

```go
func (d *Disk) RunDefragmentation() {
	rightIndex := len(d.Blocks) - 1

	movedEnds := make(map[int]int)
	var fileStart, fileEnd, fileSize int

	// Here we are going to iterate from the right to the left
	for rightIndex >= 0 {
		// We don't care about empty blocks on the right
		if d.Blocks[rightIndex] == emptyFID {
			rightIndex--
			continue
		}
        // Skip map for the files that were moved to the left
		if nextFileEnd, ok := movedEnds[rightIndex]; ok {
			rightIndex = nextFileEnd
			continue
		}

		// No need to proceed if we are at the beginning of the disk (last file)
		fileStart = d.SeekFileStart(rightIndex)
		if fileStart == 0 {
			break
		}
		fileEnd, rightIndex = rightIndex, fileStart-1
		fileSize = fileEnd - fileStart + 1

		emptySize := d.FindLeftestEmptyFit(fileSize)
		if emptySize == -1 {
			continue
		}
		emptyBlocks := d.EmptyCatalog[emptySize]

		// If the first fitting empty block is to the right of the file,
		// than we can't use it
		firstEmptyBlock := emptyBlocks[0]
		if firstEmptyBlock > fileStart {
			continue
		}
		d.EmptyCatalog[emptySize] = slices.Clone(emptyBlocks[1:])

		d.MoveFileToEmptyBlock(fileStart, fileEnd, firstEmptyBlock)
		// The skip map mentioned above is set here to the next left block from
		// found empty block
		movedEnds[fileEnd] = firstEmptyBlock - 1

		// If it was not perfect fit, we need to update the empty catalog
		if emptySize == fileSize {
			continue
		}
		newEmptySize := emptySize - fileSize
		newEmptyIndex := firstEmptyBlock + fileSize
		d.UpdateEmptyCatalog(newEmptySize, newEmptyIndex)
	}
}
```

The `SeekFileStart` method is simple iteration and file ID check:
```go
func (d *Disk) SeekFileStart(fileEnd int) int {
	if fileEnd >= len(d.Blocks) {
		panic(fmt.Sprintf("disk index out of bounds: %d vs %d", fileEnd, len(d.Blocks)))
	}

	fileID := d.Blocks[fileEnd]

	fileStart := fileEnd
	for {
		if fileStart == 0 || d.Blocks[fileStart-1] != fileID {
			break
		}
		fileStart--
	}
	return fileStart
}
```

To find the leftmost empty space for the file, we need to iterate over the empty
spaces buckets and choose the leftmost one.
NB: catalog is kept sorted via `UpdateEmptyCatalog` after file moving.
Thus we can compare and take only the first element from the bucket:

```go
func (d *Disk) FindLeftestEmptyFit(fileSize int) int {
	minEmptyIndex := math.MaxInt32
	foundSize := -1
	// We check all buckets from the current file size
	// and choose the one with the smallest index
	for emptySize := fileSize; emptySize < 10; emptySize++ {
		if len(d.EmptyCatalog[emptySize]) == 0 {
			return -1
		}
		if d.EmptyCatalog[emptySize][0] < minEmptyIndex {
			minEmptyIndex = d.EmptyCatalog[emptySize][0]
			foundSize = emptySize
		}
	}
	return foundSize
}

func (d *Disk) UpdateEmptyCatalog(size, index int) {
	emptyBlocks := d.EmptyCatalog[size]
	emptyBlocks = append(emptyBlocks, index)
	slices.Sort(emptyBlocks)
	d.EmptyCatalog[size] = emptyBlocks
}
```

Moving the file is more a technical task and "off by one" errors source:

```go
func (d *Disk) MoveFileToEmptyBlock(fileStart, fileEnd int, emptyStart int) {
	fileID := d.Blocks[fileStart]
	emptyOffset := fileEnd - fileStart
	d.ChangeSegmentValue(emptyStart, emptyStart+emptyOffset, fileID)
	d.DeleteBlocks(fileStart, fileEnd)
}

func (d *Disk) DeleteBlocks(start, end int) {
	d.ChangeSegmentValue(start, end, emptyFID)
}

func (d *Disk) ChangeSegmentValue(start, end int, val FileID) {
	for i := start; i <= end; i++ {
		if val != emptyFID && d.Blocks[i] != emptyFID {
			panic(
				fmt.Sprintf(
					"Trying to write a non-empty block %d [%d:%d] with %d",
					d.Blocks[i],
					start,
					end,
					val,
				),
			)
		}
		d.Blocks[i] = val
	}
}
```

## Tags
- two pointers
