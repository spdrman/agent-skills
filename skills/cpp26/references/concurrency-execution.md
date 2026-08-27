# Concurrency, Atomics, Coroutines, and C++26 Execution

## First Principle

Prefer no shared mutable state.

Good concurrency architecture often comes from:
- ownership partitioning;
- immutable snapshots;
- messages;
- task-local state;
- sharding.

## Mutexes

Use RAII lock types.

Prefer:
- `lock_guard` for simple scope;
- `unique_lock` when flexibility/condition variable required;
- `scoped_lock` for multiple locks.

Define lock ordering.

Avoid:
- callbacks under locks;
- blocking I/O under locks;
- recursive mutex as design patch.

## Condition Variables

Wait in a predicate loop.

Handle spurious wakeups.

Define shutdown wakeup behavior.

## Atomics

Use atomics only with a synchronization proof.

For each atomic state:
- what data does it publish?
- what operation synchronizes with what?
- what ordering is needed?
- what lifetime protects pointed-to data?
- is ABA possible?

Defaulting everything to relaxed is wrong.

Defaulting complex algorithms to relaxed-plus-comments is worse.

Prefer a mutex when performance is adequate.

## Lock-Free

Lock-free code requires:
- linearization point;
- memory-order proof;
- reclamation strategy;
- progress guarantee;
- ABA strategy;
- exhaustive stress/model tests.

Do not use lock-free for prestige.

## Hazard Pointers

C++26 standardized hazard-pointer facilities support safe reclamation patterns.

They do not define your data-structure algorithm.

Verify:
- publication;
- protection;
- retirement;
- reclamation;
- thread registration/lifetime.

## RCU

RCU is appropriate for read-mostly data where:
- readers need very low overhead;
- update/reclamation model fits;
- grace-period semantics are understood.

Do not use RCU when a shared mutex is simpler and fast enough.

## `jthread`

Prefer `std::jthread` over raw `std::thread` where cooperative stop/join semantics fit.

Define cancellation responsiveness.

Do not detach threads without a process-lifetime ownership design.

## Stop Tokens

Cancellation is cooperative.

Define:
- where stop requests originate;
- which operations observe them;
- cleanup;
- partial results;
- whether cancellation is an error.

## Coroutines

Coroutines are a language mechanism, not a scheduler.

Audit:
- frame ownership;
- suspension lifetime;
- exception propagation;
- cancellation;
- destruction before completion;
- references spanning suspension;
- executor/thread affinity.

Never keep a lock guard across `co_await` unless the design explicitly requires it and deadlock/reentrancy is understood.

## C++26 Execution Control

C++26 execution introduces sender/receiver vocabulary for describing/composing asynchronous operations.

Use it for:
- dependency graphs;
- scheduler-neutral async;
- composable cancellation;
- structured completion channels.

Do not use it merely to make synchronous code look modern.

## Sender Review

For each sender chain define:
- value completion;
- error completion;
- stopped completion;
- scheduler/execution context;
- allocation/lifetime;
- cancellation propagation.

## Backpressure

Async does not remove capacity limits.

Bound:
- queues;
- in-flight operations;
- task spawning;
- memory.

Avoid unbounded producer pipelines.

## Shutdown

Shutdown is part of the architecture.

Define order:
1. stop accepting work;
2. request cancellation;
3. drain/complete;
4. release shared state;
5. join worker resources.

Test shutdown during every major state.

## Testing Concurrent Code

Use:
- stress tests;
- deterministic scheduler/model checking where available;
- ThreadSanitizer;
- fault injection;
- repeated shutdown/restart;
- randomized delays in test builds.

A million passing runs are not a proof, but they are useful evidence.
