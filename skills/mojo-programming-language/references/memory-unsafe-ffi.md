# Mojo Unsafe Memory, Pointers, Python, C/C++, and ABI Reference

## UnsafePointer Policy

Use `UnsafePointer` only when manual memory or foreign interoperability actually requires it. Prefer safer pointer/span abstractions for normal borrowed memory.

## Pointer Proof

Before every unsafe load/store or arithmetic operation establish:

- pointer/allocation is live;
- address is in the correct allocation/address space;
- non-nullness where required;
- alignment;
- initialized state for reads;
- writable state for writes;
- legal index/offset/range;
- non-overflowing arithmetic;
- legal stride;
- correct aliasing/mutation behavior;
- type representation matches stored data.

For vector operations, prove the entire accessed lane set is valid.

## Allocation

For manual allocation:

- check count/size arithmetic;
- define owner;
- pair with correct deallocator;
- free exactly once;
- track initialized elements during staged construction;
- destroy initialized elements if construction fails;
- keep pointer with count/capacity metadata.

Never free foreign memory unless the foreign API transfers ownership and specifies the deallocator.

## Origins

Origin tracking helps lifetime/alias analysis but is not bounds checking. External-origin allocation remains manually managed.

## Alignment and Initialization

Do not reinterpret byte storage as typed storage unless alignment and representation are valid. Never read uninitialized elements. Track initialized prefixes/ranges explicitly.

## Byte Order and Bit Reinterpretation

For file/network/foreign formats specify endianness and distinguish numeric conversion from bit reinterpretation. Avoid native-struct byte dumps as stable formats.

## C ABI

C ABI support is version-sensitive. Verify the pinned compiler supports the required calling convention and aggregate behavior.

Specify calling convention, symbol, exact widths, struct layout, pointer mutability, nullability, ownership, array lengths, strings, callbacks, threading, and error mapping.

## C/C++ Ownership Patterns

Prefer explicit patterns:

- borrow pointer+length for call duration;
- caller allocates / callee fills;
- callee allocates / exported matching free;
- opaque handle / explicit destroy.

Avoid boundaries where either side could plausibly believe the other owns memory.

## C++ Exceptions

Do not allow C++ exceptions to cross unsupported language/ABI boundaries. Catch and translate in a C++ shim when needed.

## Python Interop

For every conversion determine whether it copies, shared-buffer lifetime, dtype, contiguity/layout, device, and exception behavior.

Do not keep a raw pointer into Python-owned storage after the Python object may resize/free it.

## Python Performance

Use Python at orchestration boundaries. Avoid per-element Python calls, repeated boxing/unboxing, callbacks inside hot kernels, and repeated host/device conversions. Batch work across the boundary.

## Strings

Define encoding. C NUL termination does not imply UTF-8. Python text does not map to C strings without deliberate conversion.

## Callbacks

Define registration lifetime, state ownership, concurrent invocation, callback thread, reentrancy, deregistration races, and errors. Never pass stack-local state to a callback that can outlive the function.

## Device Pointers

Track address space and device ownership. Host and device pointers are not interchangeable unless the runtime explicitly guarantees appropriate unified access. Never dereference device-only memory from host code.

## Safe Wrapper Requirement

When unsafe operations repeat, create a narrow abstraction that owns the proof. Expose operations whose preconditions are checked or statically represented; keep unsafe implementation local.
