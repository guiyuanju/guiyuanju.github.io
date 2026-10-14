(:title "Swap Nodes in Pairs -- Iterative vs Recursive"
 :date "2025-03-12")

[24. Swap Nodes in Pairs](https://leetcode.com/problems/swap-nodes-in-pairs/)

Given a linked list, swap every two adjacent nodes and return its head. You must solve the problem without modifying the values in the list's nodes (i.e., only nodes themselves may be changed.)

Example:
Input: head = [1,2,3,4]
Output: [2,1,4,3]

Iterative solution:

```go
func swapPairs(head *ListNode) *ListNode {
	if head == nil || head.Next == nil {
		return head
	}

	dump := head.Next
	var prev *ListNode
	for head != nil && head.Next != nil {
		if prev != nil {
			prev.Next = head.Next
		}
		next := head.Next.Next
		head.Next.Next = head
		head.Next = next

		prev = head
		head = head.Next
	}

	return dump
}
```

Recursive solution:

```go
func swapPairs(head *ListNode) *ListNode {
	if head == nil || head.Next == nil {
		return head
	}

	dump := head.Next
	next := head.Next.Next
	head.Next.Next = head
	head.Next = swapPairs(next)
	return dump
}
```

Im my opinion, the recursive solution is much more easily to come up with and understand.
