(:title "Some Useful Helper Functions in Go for Leetcode -- Linked List, Tree, Graph"
 :date "2025-04-01"
 :draft t)

## Assertion

```go
func assertEq[T comparable](a, b T) {
	if a != b {
		fmt.Printf("Failed: %v != %v\n", a, b)
	} else {
		fmt.Printf("Ok: %v\n", a)
	}
}
```

## Linked List

```go
// LeetCode linked list definition
type ListNode struct {
	Val  int
	Next *ListNode
}

// create a linked list with an array of ints
func makeList(vals []int) *ListNode {
	head := &ListNode{0, nil}
	prev := head
	for _, v := range vals {
		prev.Next = &ListNode{v, nil}
		prev = prev.Next
	}
	return head.Next
}

// print a linked list
func printList(head *ListNode) {
	fmt.Print("[")
	for head != nil {
		fmt.Printf("%d, ", head.Val)
		head = head.Next
	}
	fmt.Println("]")
}
```

## Binary Tree

```go
// LeetCode binary tree definition
type TreeNode struct {
	Val   int
	Left  *TreeNode
	Right *TreeNode
}

// create a bianry tree given an array of `int` or `nil`
// e.g. root := makeBinaryTree([]any{1, 2, 3, nil, nil, 4, 5})
// will produce a binary tree:
//           1
//     2           3
// nil   nil     4   5
func makeBinaryTree(nodes []any) *TreeNode {
	var root *TreeNode
	queue := []*TreeNode{}
	for i, n := range nodes {
		var cur *TreeNode
		if n != nil {
			cur = &TreeNode{
				Val:   n.(int),
				Left:  nil,
				Right: nil,
			}
		}
		queue = append(queue, cur)

		for queue[0] == nil {
			queue = queue[1:]
		}

		if i == 0 {
			root = cur
		} else if i%2 != 0 {
			queue[0].Left = cur
		} else {
			queue[0].Right = cur
			queue = queue[1:]
		}
	}
	return root
}

// print a bianry tree
func printBinaryTree(root *TreeNode) {
	flat := []*TreeNode{}
	queue := []*TreeNode{root}
	for len(queue) > 0 {
		cur := queue[0]
		queue = queue[1:]
		flat = append(flat, cur)
		if cur != nil {
			queue = append(queue, cur.Left)
			queue = append(queue, cur.Right)
		}
	}
	for i := len(flat) - 1; i >= 0 && flat[i] == nil; i-- {
		flat = flat[:len(flat)-1]
	}
	fmt.Print("[")
	for i, v := range flat {
		if v != nil {
			fmt.Print(v.Val)
		} else {
			fmt.Print("null")
		}
		if i < len(flat)-1 {
			fmt.Print(", ")
		}
	}
	fmt.Println("]")
}
```

## Matrix, 2D Array

Parse 2D array:

```go
func parse2DArray(s string) [][]int {
	s = s[1 : len(s)-1]
	parts := strings.Split(s, "],[")
	var res [][]int
	for _, p := range parts {
		p = strings.Trim(p, "[]")
		ints := strings.Split(p, ",")
		var cur []int
		for _, i := range ints {
			n, err := strconv.ParseInt(i, 10, 0)
			if err != nil {
				panic(err)
			}
			cur = append(cur, int(n))
		}
		res = append(res, cur)
	}
	return res
}

// no spaces in the provided string
matrix := parse2DArray("[[1,2,3],[4,5,6]]")
// matrix = [][]int{{1, 2, 3}, {4, 5, 6}}
```
