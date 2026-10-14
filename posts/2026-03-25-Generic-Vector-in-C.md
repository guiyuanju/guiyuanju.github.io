(:title "\"Generic\" Vector in C From Scratch"
 :date "2026-02-02")

[github repo](https://github.com/guiyuanju/vector)

A vector is a dynamically growable array allocated on heap, the concept is similar to `ArrayList` in Java or `slice` in Go (slice is actually a little different).

C lacks such convenient data structure, but we can build one with an easy to use interface by ourselves.

First define the Vec structure, a dynamic array should have a `len` indicating the actual length of data in the underlying storage, `cap` tells us the length of the storage, and `size` is quite interesting here, which represents the byte size of a single data element we store in this vector, because C doesn't have generic, and there is no type info during runtime, we need some way to know our type, so that we can retrieve the data from the bytes stored in storage using its byte size, and at last, we have the `data`, which is the underlying storage to store all our elements, in bytes.

```c
typedef struct {
  size_t len;
  size_t cap;
  size_t size;  // size of an element
  char data[];  // flexible array member
} Vec;
```

The `data` is a flexible array member of this structure, it doesn't occupy any space, just a name that we can use to get the pointer to the end of our Vec structure. We have a special way to allocate the storage: we treat our Vec structure as a header, and we allocate more space than a Vec structure needs, the extra space is used for the actual storage.

```c
void* vec_new(size_t len, size_t cap, size_t size) {
  // malloc the size of Vec and size * cap, that is the initial space specified
  Vec* vector = (Vec*)malloc(offsetof(Vec, data) + size * cap);
  vector->len = len;
  vector->cap = cap;
  vector->size = size;
  // return the data, instead of the Vec
  return (void*)(vector->data);
}
```

Look at the `return (void*)(vector->data)`, the function is not returning a pointer to the `Vec`, but the `data` member, why do we do this? Because user now gets a real array of elements, not a custom type, which enables the familiar array index syntax like `data[i]`, without the need for a custom function like `vec_get(vec, idx)`, `vec_set(vec, idx, val)`, provides a simple interface.

```c
int* vec = vec_new(4, 4, sizeof(int));
vec[0] = 10;
```

We could define a macro `vnew` to simplify the interface further.

```c
#define vnew(type, len) vec_new(len, len, sizeof(type))
```

With `vnew` defined, we can use it as if we have generics in C.

```c
int* vec = vnew(int, 4);
vec[0] = 10;
```

Okay, we have a fixed length array, how to make our vector growable? We need a function to actually do the job, below is a `vec_grow` function that takes a vector data and grow it.

```c
void* vec_grow(void* vector) {
  Vec* header = vheader(vector);
  if (header->cap >= 8) {
    header->cap += header->cap / 2;
  } else {
    header->cap = 8;
  }
  header = realloc(header, offsetof(Vec, data) + header->cap * header->size);
  return (void*)(header->data);
}
```

We are using a simple grow strategy here: if the vector is less than 8, we grow to 8 directly, this is to reduce the number of expensive grow when vector size is small; and if the size is bigger than 8, grow 1.5x size. Note that we are using a macro `vheader` in the function to get the `Vec` structure back from the plain data, the definition is as below, which simply offset the pointer backwards to "reveal" the **hidden** structure.

```c
#define vheader(vector) ((Vec*)((char*)(vector) - offsetof(Vec, data)))
```

Since we have a function to grow our vector, we can automatically call it when user pushes a new element to the vector, we need a custom macro for it, which checks if the length overflow the capacity, grow the vector, set value, and update vector metadata.

```c
#define vadd(vector, value)                         \
  do {                                              \
    if ((vector) == NULL) {                         \
      vector = vec_new(0, 4, sizeof(*vector));      \
    }                                               \
    if (vlen(vector) + 1 > vcap(vector)) {          \
      vector = vec_grow(vector);                    \
    }                                               \
    (vector)[vlen(vector)] = (value);               \
    vheader(vector)->len++;                         \
  } while (0)
```

In the `vadd` macro, there is a `if` branch which checks if vector is `NULL`, if it is, create a vector for the user, this is quite convenient, you don't need to use `vnew` now, just declare the type and `vadd`, so dynamic!

```c
// uninitialized vector
float* fvec = NULL;
vadd(fvec, 1.0);
```

There are some little helper macros here:

```c
#define vfree(vector) (free(vheader(vector)))
#define vlen(vector) (vheader(vector)->len)
#define vcap(vector) (vheader(vector)->cap)
#define vnew2(type, len, cap) vec_new(len, cap, sizeof(type))
```

At the end, combining all of the above, we get a easy-to-use, "generic" vector, which feels magical!

```c
   // new vector with len
    int* vec = vnew(int, 4);
    printf("len = %zu, cap = %zu\n", vlen(vec), vcap(vec));
    for (size_t i = 0; i < vlen(vec); i++) {
        vec[i] = i;
    }
    for (size_t i = vlen(vec); i < 10; i++) {
        vadd(vec, i);
    }
    for (size_t i = 0; i < vlen(vec); i++) {
        printf("%d ", vec[i]);
    }
    printf("\nlen = %zu, cap = %zu\n", vlen(vec), vcap(vec));
    vfree(vec);

    // uninitialized vector
    float* fvec = NULL;
    vadd(fvec, 1.0);
    vadd(fvec, 2.0);
    vadd(fvec, 3.0);
    for (size_t i = 0; i < vlen(fvec); i++) {
        printf("%f ", fvec[i]);
    }
    vfree(fvec);
```
