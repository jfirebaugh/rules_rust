# [Rules rust](https://github.com/bazelbuild/rules_rust)

## Overview

This repository provides rules for building [Rust][rust] projects with [Bazel][bazel].

[bazel]: https://bazel.build/
[rust]: http://www.rust-lang.org/

<!-- TODO: Render generated docs on the github pages site again, https://bazelbuild.github.io/rules_rust/ -->

<a name="setup"></a>

## Setup

To use the Rust rules, add the following to your `WORKSPACE` file to add the external repositories for the Rust toolchain:

```python
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# To find additional information on this release or newer ones visit:
# https://github.com/bazelbuild/rules_rust/releases
http_archive(
    name = "rules_rust",
    sha256 = "696b01deea96a5e549f1b5ae18589e1bbd5a1d71a36a243b5cf76a9433487cf2",
    urls = ["https://github.com/bazelbuild/rules_rust/releases/download/0.11.0/rules_rust-v0.11.0.tar.gz"],
)

load("@rules_rust//rust:repositories.bzl", "rules_rust_dependencies", "rust_register_toolchains")

rules_rust_dependencies()

rust_register_toolchains()
```

The rules are released, and releases can be found on [the GitHub Releases page](https://github.com/bazelbuild/rules_rust/releases). We recommend using the latest release from that page.

## Rules

- [defs](defs.md): standard rust rules for building and testing libraries and binaries.
- [rust_doc](rust_doc.md): rules for generating and testing rust documentation.
- [rust_clippy](rust_clippy.md): rules for running [clippy](https://github.com/rust-lang/rust-clippy#readme).
- [rust_fmt](rust_fmt.md): rules for running [rustfmt](https://github.com/rust-lang/rustfmt#readme).
- [rust_proto](rust_proto.md): rules for generating [protobuf](https://developers.google.com/protocol-buffers) and [gRPC](https://grpc.io) stubs.
- [rust_bindgen](rust_bindgen.md): rules for generating C++ bindings.
- [rust_wasm_bindgen](rust_wasm_bindgen.md): rules for generating [WebAssembly](https://www.rust-lang.org/what/wasm) bindings.
- [cargo](cargo.md): Rules dedicated to Cargo compatibility. ie: [`build.rs` scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html).
- [crate_universe](crate_universe.md): Rules for generating Bazel targets for external crate dependencies.

You can also browse the [full API in one page](flatten.md).

### Experimental rules

- [rust_analyzer](rust_analyzer.md): rules for generating `rust-project.json` files for [rust-analyzer](https://rust-analyzer.github.io/)

## Specifying Rust version

To build with a particular version of the Rust compiler, pass that version to [`rust_register_toolchains`](flatten.md#rust_register_toolchains):

```python
rust_register_toolchains(version = "1.62.1", edition="2018")
```

As well as an exact version, `version` can be set to `"nightly"` or `"beta"`. If set to these values, `iso_date` must also be set:

```python
rust_register_toolchains(version = "nightly", iso_date = "2022-07-18", edition="2018")
```

Similarly, `rustfmt_version` may also be configured:

```python
rust_register_toolchains(rustfmt_version = "1.62.1")
```

## External Dependencies

[crate_universe](crate_universe.md) is a tool built into `rules_rust` that can be used to fetch dependencies. Additionally, [cargo-raze](https://github.com/google/cargo-raze) is an older third-party which can also fetch dependencies.

## Supported bazel versions

The oldest version of Bazel the `main` branch is tested against is `5.0.0`. Previous versions may still be functional in certain environments, but this is the minimum version we strive to fully support.

We test these rules against the latest rolling releases of Bazel, and aim for compatibility with them, but prioritise stable releases over rolling releases where necessary.

## Supported platforms

We aim to support Linux, macOS, and Windows.

Windows support is less complete than the other two platforms, but most things work, and we welcome contributions to help improve its support.

Windows support for some features requires `--enable_runfiles` to be passed to Bazel, we recommend putting it in your bazelrc. See [Using Bazel on Windows](https://bazel.build/configure/windows) for more Windows-specific recommendations.
