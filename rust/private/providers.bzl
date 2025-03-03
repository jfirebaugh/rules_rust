# Copyright 2021 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Module containing definitions of all Rust providers."""

CrateInfo = provider(
    doc = "A provider containing general Crate information.",
    fields = {
        "aliases": "Dict[Label, String]: Renamed and aliased crates",
        "compile_data": "depset[File]: Compile data required by this crate.",
        "deps": "depset[DepVariantInfo]: This crate's (rust or cc) dependencies' providers.",
        "edition": "str: The edition of this crate.",
        "is_test": "bool: If the crate is being compiled in a test context",
        "name": "str: The name of this crate.",
        "output": "File: The output File that will be produced, depends on crate type.",
        "owner": "Label: The label of the target that produced this CrateInfo",
        "proc_macro_deps": "depset[DepVariantInfo]: This crate's rust proc_macro dependencies' providers.",
        "root": "File: The source File entrypoint to this crate, eg. lib.rs",
        "rustc_env": "Dict[String, String]: Additional `\"key\": \"value\"` environment variables to set for rustc.",
        "srcs": "depset[File]: All source Files that are part of the crate.",
        "type": (
            "str: The type of this crate " +
            "(see [rustc --crate-type](https://doc.rust-lang.org/rustc/command-line-arguments.html#--crate-type-a-list-of-types-of-crates-for-the-compiler-to-emit))."
        ),
        "wrapped_crate_type": (
            "str, optional: The original crate type for targets generated using a previously defined " +
            "crate (typically tests using the `rust_test::crate` attribute)"
        ),
    },
)

DepInfo = provider(
    doc = "A provider containing information about a Crate's dependencies.",
    fields = {
        "dep_env": "File: File with environment variables direct dependencies build scripts rely upon.",
        "direct_crates": "depset[AliasableDepInfo]",
        "link_search_path_files": "depset[File]: All transitive files containing search paths to pass to the linker",
        "transitive_build_infos": "depset[BuildInfo]",
        "transitive_crate_outputs": "depset[File]: All transitive crate outputs.",
        "transitive_crates": "depset[CrateInfo]",
        "transitive_noncrates": "depset[LinkerInput]: All transitive dependencies that aren't crates.",
    },
)

BuildInfo = provider(
    doc = "A provider containing `rustc` build settings for a given Crate.",
    fields = {
        "dep_env": "File: extra build script environment varibles to be set to direct dependencies.",
        "flags": "File: file containing additional flags to pass to rustc",
        "link_flags": "File: file containing flags to pass to the linker",
        "link_search_paths": "File: file containing search paths to pass to the linker",
        "out_dir": "File: directory containing the result of a build script",
        "rustc_env": "File: file containing additional environment variables to set for rustc.",
    },
)

DepVariantInfo = provider(
    doc = "A wrapper provider for a dependency of a crate. The dependency can be a Rust " +
          "dependency, in which case the `crate_info` and `dep_info` fields will be populated, " +
          "a Rust build script dependency, in which case `build_info` will be populated, or a " +
          "C/C++ dependency, in which case `cc_info` will be populated.",
    fields = {
        "build_info": "BuildInfo: The BuildInfo of a Rust dependency",
        "cc_info": "CcInfo: The CcInfo of a C/C++ dependency",
        "crate_info": "CrateInfo: The CrateInfo of a Rust dependency",
        "dep_info": "DepInfo: The DepInfo of a Rust dependency",
    },
)

StdLibInfo = provider(
    doc = (
        "A collection of files either found within the `rust-stdlib` artifact or " +
        "generated based on existing files."
    ),
    fields = {
        "alloc_files": "List[File]: `.a` files related to the `alloc` module.",
        "between_alloc_and_core_files": "List[File]: `.a` files related to the `compiler_builtins` module.",
        "between_core_and_std_files": "List[File]: `.a` files related to all modules except `adler`, `alloc`, `compiler_builtins`, `core`, and `std`.",
        "core_files": "List[File]: `.a` files related to the `core` and `adler` modules",
        "dot_a_files": "Depset[File]: Generated `.a` files",
        "self_contained_files": "List[File]: All `.o` files from the `self-contained` directory.",
        "srcs": "List[Target]: All targets from the original `srcs` attribute.",
        "std_files": "Depset[File]: `.a` files associated with the `std` module.",
        "std_rlibs": "List[File]: All `.rlib` files",
    },
)

CaptureClippyOutputInfo = provider(
    doc = "Value of the `capture_clippy_output` build setting",
    fields = {"capture_output": "Value of the `capture_clippy_output` build setting"},
)

ClippyInfo = provider(
    doc = "Provides information on a clippy run.",
    fields = {
        "output": "File with the clippy output.",
    },
)
