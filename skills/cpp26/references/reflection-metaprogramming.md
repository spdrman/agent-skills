# C++26 Reflection and Reflective Metaprogramming

## Mission

Use C++26 reflection to eliminate repetitive, fragile, macro-heavy, or trait-heavy compile-time machinery while preserving readable interfaces, bounded compile-time cost, and understandable generated code.

Reflection is not an invitation to move the whole program into compile time.

## Capability Check

Before generating reflection code:

- confirm C++26 mode;
- confirm the required compiler implementation;
- check `__cpp_impl_reflection`;
- check `__cpp_lib_reflection`;
- include `<meta>`;
- compile a minimal example on the exact toolchain.

Compiler support is still uneven. Do not assume support from `-std=c++26` alone.

## Reflection Domain

Reflection produces values of type:

```cpp
std::meta::info
```

Conceptually, a reflection value describes a program entity at compile time.

The reflection operator is:

```cpp
^^entity
```

Examples:

```cpp
constexpr auto r_type = ^^int;
constexpr auto r_class = ^^MyType;
constexpr auto r_member = ^^MyType::field;
constexpr auto r_enum = ^^Color::red;
```

Do not use obsolete Reflection TS `reflexpr` syntax.

## Splicing

Splicing converts reflected entities back into grammatical C++ constructs:

```cpp
[: r :]
```

Depending on context, a splice can designate a type, value, function, member, namespace, or template construct supported by the language.

Type example:

```cpp
constexpr auto r = ^^int;
using T = [: r :];
```

Member access can use a splice where supported:

```cpp
obj.[: member_reflection :]
```

Rules:

- prefer named reflection variables for complex operations;
- avoid deeply nested reflection expressions in user-facing code;
- treat splicing as code generation and review the resulting semantic entity;
- keep access-control context in mind.

## `<meta>`

`<meta>` provides the reflection library.

Important categories include:

### Identity and classification

- `std::meta::is_type`
- `std::meta::is_function`
- `std::meta::is_class_member`
- `std::meta::is_nonstatic_data_member`
- `std::meta::is_enum_type`
- `std::meta::is_template`
- many corresponding type-property predicates.

Use semantic queries instead of reconstructing identity from strings.

### Names and source

- identifier queries;
- display-string queries;
- source location queries.

Do not use textual names as stable IDs unless the API explicitly defines them that way.

### Scope queries

- current function;
- current class;
- current namespace.

Use these sparingly in diagnostics/generation; avoid hidden coupling to lexical location.

### Member and subobject queries

Important facilities include:

- `members_of`;
- `bases_of`;
- `static_data_members_of`;
- `nonstatic_data_members_of`;
- `subobjects_of`;
- `enumerators_of`.

Access matters. Queries can use an access context and may fail/omit inaccessible entities according to the facility.

Do not assume reflection bypasses encapsulation.

### Layout queries

Facilities include:

- `offset_of`;
- `size_of`;
- `alignment_of`;
- `bit_size_of`.

Use these for compile-time layout-aware generation when necessary.

Do not turn class layout into a serialized ABI unless that is explicitly the contract.

## Expansion Statements

Reflection becomes substantially more usable with C++26 `template for`.

Pattern:

```cpp
template <class T>
void visit_fields(T& obj) {
    template for (constexpr auto m :
                  std::meta::nonstatic_data_members_of(^^T, /* context */)) {
        auto&& field = obj.[:m:];
        // operate on field
    }
}
```

Exact access-context syntax depends on the selected standard-library API and implementation; verify on the toolchain.

`template for` is compile-time expansion, not runtime iteration.

Audit:

- number of generated instantiations;
- compile-time memory;
- diagnostics;
- code size;
- duplicated operations.

## Enum Reflection

Reflection can replace many manual enum maps.

Conceptual pattern:

```cpp
template<class E>
std::string_view enum_name(E value) {
    template for (constexpr auto e : std::meta::enumerators_of(^^E)) {
        if (value == [:e:]) {
            return std::meta::identifier_of(e);
        }
    }
    return {};
}
```

Verify exact library return types and string-storage rules on the implementation.

Design questions:

- what happens for non-enumerator numeric values?
- is the textual enumerator name an API?
- should aliases/duplicate underlying values be supported?
- is the result stable across renaming?

Do not expose reflected source identifiers as persistent wire values without explicit policy.

## Structural Serialization

Reflection can remove repetitive field listing, but serialization still requires a schema policy.

Before implementing generic reflection serialization, define:

- which members participate;
- field naming;
- versioning;
- optional/default values;
- ignored/transient fields;
- private member access;
- base classes;
- pointer/reference handling;
- containers;
- cycles;
- endian/encoding;
- unknown-field behavior;
- backward/forward compatibility.

Reflection removes boilerplate; it does not solve schema evolution.

Prefer annotations or explicit traits for semantic policy rather than "serialize every member."

## Annotations

C++26 reflection includes annotation-query support.

Use annotations for opt-in metadata such as:

- serialization field names;
- RPC exposure;
- validation rules;
- persistence flags;
- UI metadata;
- code-generation markers.

Rules:

- annotations should express semantic policy;
- avoid a second opaque configuration language;
- keep annotation types small and strongly typed;
- define whether inheritance/overrides apply;
- test generated behavior.

## Reflection Substitution

Facilities such as `substitute` and `can_substitute` support constructing/referring to template instantiations through reflection.

Use when it materially simplifies type-level transformation.

Do not use reflection substitution when an ordinary alias template or concept is clearer.

## Reflecting Constants, Objects, and Functions

Reflection facilities can create reflection values representing compile-time constants, objects, or functions.

Use them to bridge normal constexpr values and reflection-based APIs.

Keep object lifetime/static-storage rules explicit.

## Promoting Compile-Time Data to Static Storage

C++26 `<meta>` provides facilities to promote compile-time strings/arrays/objects into static storage.

This enables generated lookup tables, names, descriptors, and metadata.

Review:

- binary size;
- duplicate generated objects;
- linkage/ODR;
- pointer stability;
- whether runtime construction would be simpler.

## Aggregate Definition / Code Generation

C++26 reflection includes facilities such as data-member specifications and aggregate definition.

Use generation for repetitive structural types where:
- generated representation has clear semantics;
- the resulting type remains debuggable;
- ABI is not accidentally tied to implementation detail;
- diagnostics remain tolerable.

Do not generate public ABI types casually.

## Reflection vs Concepts

Use concepts to constrain what operations a generic algorithm requires.

Use reflection to inspect structure/metadata.

Do not replace a semantic concept with a structural reflection predicate when behavior is what matters.

Bad idea:
- "type has a method named `serialize`"

Better:
- define a `Serializable` concept based on valid semantic operations.

## Reflection vs Macros

Prefer reflection over macros when reflection can express the same relationship with:

- type safety;
- scope awareness;
- compiler diagnostics;
- no duplicated field list.

Keep macros for build/configuration/platform cases that are genuinely preprocessor concerns.

## Reflection vs Code Generation Tools

External codegen remains appropriate when:

- multiple languages share a schema;
- build-time artifacts need to be inspected;
- protocol compatibility is external;
- generated source is part of a public SDK;
- the compiler need not understand the source schema.

Reflection is best for C++-native compile-time knowledge.

## Compile-Time Cost Budget

Reflection can generate enormous work.

Track:
- number of reflected entities;
- expansion count;
- template depth;
- constexpr allocation;
- generated diagnostics;
- object size;
- incremental build impact.

Build-time regressions are performance regressions.

## Encapsulation

Reflection must not become an excuse to make representation part of every subsystem's contract.

Prefer:
- public semantic interfaces;
- explicit friend/access contexts only where needed;
- generated adapters close to the type definition.

Avoid central meta-code that introspects every private implementation detail in the program.

## Stable Metadata

Never assume these are stable external identifiers unless policy says so:

- source names;
- declaration order;
- layout offsets;
- display strings;
- namespace paths.

If persistence/protocol stability matters, define explicit stable IDs.

## Diagnostics

Reflection-heavy templates can produce difficult diagnostics.

Mitigate with:

- named consteval helpers;
- small concepts;
- `static_assert` with domain messages;
- separate query/filter/generation stages;
- limited expansion scope.

Do not write one 40-line nested `consteval` expression.

## Reflection Test Strategy

Test:

- empty types;
- one member;
- bases;
- private/protected/public access;
- static vs non-static members;
- bit-fields if supported by use case;
- overloaded functions;
- enum aliases;
- annotations absent/present;
- templates;
- inherited members;
- renamed fields where schema semantics matter.

For generators, test generated type behavior, not merely successful compilation.

## Reflection Review Gate

- Is the toolchain capability verified?
- Is reflection simpler than ordinary code?
- Are semantic policies explicit?
- Is access/encapsulation preserved?
- Are compile-time costs bounded?
- Are names/layout treated as unstable unless explicitly contracted?
- Is serialization/RPC schema evolution defined?
- Is generated code testable?
- Would a concept or ordinary template be clearer?
- Is public ABI accidentally dependent on reflection output?
