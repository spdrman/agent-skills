# Resource Management, Values, Ownership, and Lifetime

## RAII

Every resource owner should satisfy:

- acquisition establishes a valid object or fails;
- object invariant includes ownership state;
- destructor releases exactly once;
- move transfers ownership safely;
- copy is either semantically valid or disabled.

## Rule of Zero

Prefer:

```cpp
class Report {
    std::string name_;
    std::vector<Row> rows_;
};
```

No destructor/copy/move code needed.

## Rule of Five

If a type directly manages a raw resource, inspect:

- destructor;
- copy constructor;
- copy assignment;
- move constructor;
- move assignment.

Prefer wrapping the raw resource in a dedicated RAII member so higher-level types return to Rule of Zero.

## `unique_ptr`

Use for polymorphic or optional unique heap ownership.

Prefer `make_unique`.

Do not use `unique_ptr` when direct object containment is simpler.

Custom deleters are appropriate for:
- C handles;
- FILE-like resources;
- OS handles;
- foreign libraries.

## `shared_ptr`

Use only when lifetime is genuinely shared.

Avoid:
- passing `shared_ptr` everywhere;
- storing it merely to keep something alive "just in case";
- cycles.

Use `weak_ptr` for observation that should not extend lifetime.

## Borrowing

Use references/pointers/views.

### Required borrow

```cpp
void process(const Config& cfg);
```

### Mutable borrow

```cpp
void normalize(Buffer& buf);
```

### Optional borrow

```cpp
void log(Logger* logger);
```

### Sequence borrow

```cpp
void parse(std::span<const std::byte> bytes);
```

## `string_view`

Great for temporary read-only text input.

Dangerous when stored beyond source lifetime.

Never return a `string_view` into a temporary/local string.

Document storage/lifetime when a class stores views.

## Move Semantics

A moved-from object must satisfy its documented valid-but-unspecified or stronger state.

Do not assume it is empty unless type guarantees it.

Mark move operations `noexcept` when they truly cannot throw; containers can exploit nothrow moves.

Do not lie with `noexcept`.

## Sink Parameters

When a function needs its own copy anyway:

```cpp
class User {
public:
    explicit User(std::string name)
        : name_(std::move(name)) {}
private:
    std::string name_;
};
```

This supports lvalues by copy and rvalues by move.

Do not apply pass-by-value sink style mechanically to expensive types where caller behavior or API constraints differ.

## Factories

Use factories when:

- construction can fail with rich error;
- derived type hidden;
- object requires shared ownership setup;
- constructor signature would expose implementation details.

Return:
- value where practical;
- `unique_ptr` for polymorphic unique ownership;
- `expected<T,E>` for explicit construction failure when appropriate.

## PImpl

Use PImpl when ABI stability, compile isolation, or dependency hiding justify it.

Costs:
- allocation/indirection;
- more implementation;
- incomplete-type/destructor considerations.

Do not PImpl small internal types without reason.

## Lifetime Hazards

Review for:

- dangling references after vector/string reallocation;
- views into moved/destroyed objects;
- lambda captures by reference escaping scope;
- coroutine captures/lifetime;
- callback user data;
- async work after owner destruction;
- reference members;
- temporary materialization;
- range/view lifetime.

## Lambda Captures

Capture intentionally.

Avoid `[&]` or `[=]` in long-lived/async closures when ownership matters.

Prefer explicit capture names.

Use move capture for ownership transfer.

## Coroutines

Coroutine frames extend lifetimes differently from ordinary calls.

Audit:
- references captured across suspension;
- `this` lifetime;
- cancellation/destruction;
- RAII in frame;
- lock guards across suspension.

## Containers and Invalidation

Know invalidation rules for:
- vector;
- string;
- deque;
- unordered containers;
- ranges/views;
- `inplace_vector`;
- `hive`.

Do not keep iterators/references across operations without guaranteed validity.

## Manual Lifetime

Placement new, `construct_at`, `destroy_at`, raw storage, `start_lifetime`, unions, and allocator internals are expert-only layers.

Encapsulate.

Test with sanitizers and multiple compilers.

Do not expose manual-lifetime requirements to ordinary callers.
