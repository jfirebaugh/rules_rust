# buildifier: disable=module-docstring
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//rust/platform:triple.bzl", "get_host_triple")
load(
    "//rust/platform:triple_mappings.bzl",
    "triple_to_constraint_set",
)
load("//rust/private:common.bzl", "DEFAULT_NIGHTLY_ISO_DATE", "rust_common")
load(
    "//rust/private:repository_utils.bzl",
    "BUILD_for_rust_analyzer_proc_macro_srv",
    "BUILD_for_rust_analyzer_toolchain",
    "BUILD_for_rust_toolchain",
    "BUILD_for_toolchain",
    "DEFAULT_STATIC_RUST_URL_TEMPLATES",
    "check_version_valid",
    "includes_rust_analyzer_proc_macro_srv",
    "load_cargo",
    "load_clippy",
    "load_llvm_tools",
    "load_rust_compiler",
    "load_rust_src",
    "load_rust_stdlib",
    "load_rustc_dev_nightly",
    "load_rustfmt",
    "should_include_rustc_srcs",
    _load_arbitrary_tool = "load_arbitrary_tool",
    "toolchain_repository_hub",
)

# Reexport `load_arbitrary_tool` as it's currently in use in https://github.com/google/cargo-raze
load_arbitrary_tool = _load_arbitrary_tool

# Note: Code in `.github/workflows/crate_universe.yaml` looks for this line, if you remove it or change its format, you will also need to update that code.
DEFAULT_TOOLCHAIN_TRIPLES = {
    "aarch64-apple-darwin": "rust_darwin_aarch64",
    "aarch64-pc-windows-msvc": "rust_windows_aarch64",
    "aarch64-unknown-linux-gnu": "rust_linux_aarch64",
    "x86_64-apple-darwin": "rust_darwin_x86_64",
    "x86_64-pc-windows-msvc": "rust_windows_x86_64",
    "x86_64-unknown-freebsd": "rust_freebsd_x86_64",
    "x86_64-unknown-linux-gnu": "rust_linux_x86_64",
}

def rules_rust_dependencies():
    """Dependencies used in the implementation of `rules_rust`."""

    maybe(
        http_archive,
        name = "platforms",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/platforms/releases/download/0.0.5/platforms-0.0.5.tar.gz",
            "https://github.com/bazelbuild/platforms/releases/download/0.0.5/platforms-0.0.5.tar.gz",
        ],
        sha256 = "379113459b0feaf6bfbb584a91874c065078aa673222846ac765f86661c27407",
    )
    maybe(
        http_archive,
        name = "rules_cc",
        urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.0.1/rules_cc-0.0.1.tar.gz"],
        sha256 = "4dccbfd22c0def164c8f47458bd50e0c7148f3d92002cdb459c2a96a68498241",
    )

    maybe(
        http_archive,
        name = "bazel_skylib",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.2.0/bazel-skylib-1.2.0.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.2.0/bazel-skylib-1.2.0.tar.gz",
        ],
        sha256 = "af87959afe497dc8dfd4c6cb66e1279cb98ccc84284619ebfec27d9c09a903de",
    )

    # Make the iOS simulator constraint available, which is referenced in abi_to_constraints()
    # rules_rust does not require this dependency; it is just imported as a convenience for users.
    maybe(
        http_archive,
        name = "build_bazel_apple_support",
        sha256 = "d94b7a0f49d735f196e1f36d2e6ef79c4e8e8b82132848dd8cd93cd82d9b12a8",
        url = "https://github.com/bazelbuild/apple_support/releases/download/1.3.0/apple_support.1.3.0.tar.gz",
    )

    # process_wrapper needs a low-dependency way to process json.
    maybe(
        http_archive,
        name = "rules_rust_tinyjson",
        sha256 = "1a8304da9f9370f6a6f9020b7903b044aa9ce3470f300a1fba5bc77c78145a16",
        url = "https://crates.io/api/v1/crates/tinyjson/2.3.0/download",
        strip_prefix = "tinyjson-2.3.0",
        type = "tar.gz",
        build_file = "@rules_rust//util/process_wrapper:BUILD.tinyjson.bazel",
    )

_RUST_TOOLCHAIN_VERSIONS = [
    rust_common.default_version,
    "nightly/{}".format(DEFAULT_NIGHTLY_ISO_DATE),
]

# buildifier: disable=unnamed-macro
def rust_register_toolchains(
        dev_components = False,
        edition = None,
        include_rustc_srcs = False,
        allocator_library = None,
        iso_date = None,
        register_toolchains = True,
        rustfmt_version = None,
        sha256s = None,
        extra_target_triples = ["wasm32-unknown-unknown", "wasm32-wasi"],
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        version = None,
        versions = []):
    """Emits a default set of toolchains for Linux, MacOS, and Freebsd

    Skip this macro and call the `rust_repository_set` macros directly if you need a compiler for \
    other hosts or for additional target triples.

    The `sha256` attribute represents a dict associating tool subdirectories to sha256 hashes. As an example:
    ```python
    {
        "rust-1.46.0-x86_64-unknown-linux-gnu": "e3b98bc3440fe92817881933f9564389eccb396f5f431f33d48b979fa2fbdcf5",
        "rustfmt-1.4.12-x86_64-unknown-linux-gnu": "1894e76913303d66bf40885a601462844eec15fca9e76a6d13c390d7000d64b0",
        "rust-std-1.46.0-x86_64-unknown-linux-gnu": "ac04aef80423f612c0079829b504902de27a6997214eb58ab0765d02f7ec1dbc",
    }
    ```
    This would match for `exec_triple = "x86_64-unknown-linux-gnu"`.  If not specified, rules_rust pulls from a non-exhaustive \
    list of known checksums..

    See `load_arbitrary_tool` in `@rules_rust//rust:repositories.bzl` for more details.

    Args:
        dev_components (bool, optional): Whether to download the rustc-dev components (defaults to False). Requires version to be "nightly".
        edition (str, optional): The rust edition to be used by default (2015, 2018, or 2021). If absent, every target is required to specify its `edition` attribute.
        include_rustc_srcs (bool, optional): Whether to download rustc's src code. This is required in order to use rust-analyzer support.
            See [rust_toolchain_repository.include_rustc_srcs](#rust_toolchain_repository-include_rustc_srcs). for more details
        allocator_library (str, optional): Target that provides allocator functions when rust_library targets are embedded in a cc_binary.
        iso_date (str, optional): The date of the nightly or beta release (ignored if the version is a specific version).
        register_toolchains (bool): If true, repositories will be generated to produce and register `rust_toolchain` targets.
        rustfmt_version (str, optional): The version of rustfmt. Either "nightly", "beta", or an exact version. Defaults to `version` if not specified.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes.
        extra_target_triples (list, optional): Additional rust-style targets that rust toolchains should support.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).
        version (str, optional): The version of Rust. Either "nightly", "beta", or an exact version. Defaults to a modern version.
        versions (list, optional): A list of toolchain versions to download. This paramter only accepts one versions
            per channel. E.g. `["1.65.0", "nightly/2022-11-02", "beta/2020-12-30"]`.
    """
    if not version and not versions:
        versions = _RUST_TOOLCHAIN_VERSIONS

    if dev_components and version != "nightly":
        fail("Rust version must be set to \"nightly\" to enable rustc-dev components")

    if not rustfmt_version:
        rustfmt_version = version

    rust_analyzer_repo_name = "rust_analyzer_{}".format(version)
    if iso_date:
        rust_analyzer_repo_name = "{}-{}".format(
            rust_analyzer_repo_name,
            iso_date,
        )

    # Detect the version of rust to pair with rust-analyzer. Allow
    # nightly toolchains to take priority.
    rust_analyzer_version = version
    rust_analyzer_iso_date = iso_date
    if not version:
        for value in versions:
            if value.startswith("nightly"):
                rust_analyzer_version, _, rust_analyzer_iso_date = value.partition("/")
                break
            if not value.startswith("beta"):
                rust_analyzer_version = value
                if not rustfmt_version:
                    rustfmt_version = value

    toolchain_names = []
    toolchain_labels = {}
    toolchain_types = {}
    exec_compatible_with_by_toolchain = {}
    target_compatible_with_by_toolchain = {}

    maybe(
        rust_analyzer_toolchain_repository,
        name = rust_analyzer_repo_name,
        version = rust_analyzer_version,
        urls = urls,
        sha256s = sha256s,
        iso_date = rust_analyzer_iso_date,
    )

    toolchain_names.append(rust_analyzer_repo_name)
    toolchain_labels[rust_analyzer_repo_name] = "@{}_srcs//:rust_analyzer_toolchain".format(
        rust_analyzer_repo_name,
    )
    exec_compatible_with_by_toolchain[rust_analyzer_repo_name] = []
    target_compatible_with_by_toolchain[rust_analyzer_repo_name] = []
    toolchain_types[rust_analyzer_repo_name] = "@rules_rust//rust/rust_analyzer:toolchain_type"


    if register_toolchains:
        native.register_toolchains("@{}//:toolchain".format(
            rust_analyzer_repo_name,
        ))

    channels = validate_channels("rust_register_toolchains", versions, iso_date, version)

    for exec_triple, name in DEFAULT_TOOLCHAIN_TRIPLES.items():
        maybe(
            rust_repository_set,
            name = name,
            dev_components = dev_components,
            edition = edition,
            exec_triple = exec_triple,
            extra_target_triples = extra_target_triples,
            include_rustc_srcs = include_rustc_srcs,
            allocator_library = allocator_library,
            iso_date = iso_date,
            register_toolchain = register_toolchains,
            rustfmt_version = rustfmt_version,
            sha256s = sha256s,
            urls = urls,
            version = version,
            versions = versions,
        )

        for toolchain in get_toolchain_repositories(name, exec_triple, extra_target_triples, channels):
            toolchain_names.append(toolchain.name)
            toolchain_labels[toolchain.name] = "@{}//:{}".format(toolchain.name + "_tools", "rust_toolchain")
            exec_compatible_with_by_toolchain[toolchain.name] = triple_to_constraint_set(exec_triple)
            target_compatible_with_by_toolchain[toolchain.name] = triple_to_constraint_set(toolchain.target_triple)
            toolchain_types[toolchain.name] = "@rules_rust//rust:toolchain"

    toolchain_repository_hub(
        name = "rust_toolchains",
        toolchain_names = toolchain_names,
        toolchain_labels = toolchain_labels,
        toolchain_types = toolchain_types,
        exec_compatible_with = exec_compatible_with_by_toolchain,
        target_compatible_with = target_compatible_with_by_toolchain,
    )

# buildifier: disable=unnamed-macro
def rust_repositories(**kwargs):
    """**Deprecated**: Use [rules_rust_dependencies](#rules_rust_dependencies) \
    and [rust_register_toolchains](#rust_register_toolchains) directly.

    Args:
        **kwargs (dict): Keyword arguments for the `rust_register_toolchains` macro.
    """
    rules_rust_dependencies()

    rust_register_toolchains(**kwargs)

def _rust_toolchain_tools_repository_impl(ctx):
    """The implementation of the rust toolchain tools repository rule."""

    check_version_valid(ctx.attr.version, ctx.attr.iso_date)

    # Conditionally download rustc sources. Generally used for `rust-analyzer`
    if should_include_rustc_srcs(ctx):
        load_rust_src(ctx)

    build_components = [
        load_rust_compiler(
            ctx = ctx,
            iso_date = ctx.attr.iso_date,
            target_triple = ctx.attr.exec_triple,
            version = ctx.attr.version,
        ),
        load_clippy(ctx),
        load_cargo(ctx),
    ]

    if ctx.attr.rustfmt_version:
        build_components.append(load_rustfmt(ctx))

    # Rust 1.45.0 and nightly builds after 2020-05-22 need the llvm-tools gzip to get the libLLVM dylib
    include_llvm_tools = ctx.attr.version >= "1.45.0" or (ctx.attr.version == "nightly" and ctx.attr.iso_date > "2020-05-22")
    if include_llvm_tools:
        build_components.append(load_llvm_tools(ctx, ctx.attr.exec_triple))

    build_components.append(load_rust_stdlib(ctx, ctx.attr.target_triple))

    stdlib_linkflags = None
    if "BAZEL_RUST_STDLIB_LINKFLAGS" in ctx.os.environ:
        stdlib_linkflags = ctx.os.environ["BAZEL_RUST_STDLIB_LINKFLAGS"].split(":")

    build_components.append(BUILD_for_rust_toolchain(
        name = "rust_toolchain",
        exec_triple = ctx.attr.exec_triple,
        include_rustc_srcs = should_include_rustc_srcs(ctx),
        allocator_library = ctx.attr.allocator_library,
        target_triple = ctx.attr.target_triple,
        stdlib_linkflags = stdlib_linkflags,
        default_edition = ctx.attr.edition,
        include_rustfmt = not (not ctx.attr.rustfmt_version),
        include_llvm_tools = include_llvm_tools,
    ))

    # Not all target triples are expected to have dev components
    if ctx.attr.dev_components:
        load_rustc_dev_nightly(ctx, ctx.attr.target_triple)

    ctx.file("WORKSPACE.bazel", "")
    ctx.file("BUILD.bazel", "\n".join(build_components))

rust_toolchain_tools_repository = repository_rule(
    doc = (
        "Composes a single workspace containing the toolchain components for compiling on a given " +
        "platform to a series of target platforms.\n" +
        "\n" +
        "A given instance of this rule should be accompanied by a toolchain_repository_proxy " +
        "invocation to declare its toolchains to Bazel; the indirection allows separating toolchain " +
        "selection from toolchain fetching."
    ),
    attrs = {
        "allocator_library": attr.string(
            doc = "Target that provides allocator functions when rust_library targets are embedded in a cc_binary.",
        ),
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details."
            ),
        ),
        "dev_components": attr.bool(
            doc = "Whether to download the rustc-dev components (defaults to False). Requires version to be \"nightly\".",
            default = False,
        ),
        "edition": attr.string(
            doc = (
                "The rust edition to be used by default (2015, 2018, or 2021). " +
                "If absent, every rule is required to specify its `edition` attribute."
            ),
        ),
        "exec_triple": attr.string(
            doc = "The Rust-style target that this compiler runs on",
            mandatory = True,
        ),
        "include_rustc_srcs": attr.bool(
            doc = (
                "Whether to download and unpack the rustc source files. These are very large, and " +
                "slow to unpack, but are required to support rust analyzer. An environment variable " +
                "`RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS` can also be used to control this attribute. " +
                "This variable will take precedence over the hard coded attribute. Setting it to `true` to " +
                "activates this attribute where all other values deactivate it."
            ),
            default = False,
        ),
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "rustfmt_version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
        ),
        "sha256s": attr.string_dict(
            doc = "A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.",
        ),
        "target_triple": attr.string(
            doc = "The Rust-style target that this compiler builds for.",
            mandatory = True,
        ),
        "urls": attr.string_list(
            doc = "A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).",
            default = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
    implementation = _rust_toolchain_tools_repository_impl,
    environ = ["RULES_RUST_TOOLCHAIN_INCLUDE_RUSTC_SRCS"],
)

def _toolchain_repository_proxy_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", BUILD_for_toolchain(
        name = "toolchain",
        toolchain = repository_ctx.attr.toolchain,
        target_settings = repository_ctx.attr.target_settings,
        toolchain_type = repository_ctx.attr.toolchain_type,
        target_compatible_with = repository_ctx.attr.target_compatible_with,
        exec_compatible_with = repository_ctx.attr.exec_compatible_with,
    ))

toolchain_repository_proxy = repository_rule(
    doc = (
        "Generates a toolchain-bearing repository that declares the toolchains from some other " +
        "rust_toolchain_repository."
    ),
    attrs = {
        "exec_compatible_with": attr.string_list(
            doc = "A list of constraints for the execution platform for this toolchain.",
        ),
        "target_compatible_with": attr.string_list(
            doc = "A list of constraints for the target platform for this toolchain.",
        ),
        "target_settings": attr.string_list(
            doc = "A list of config_settings that must be satisfied by the target configuration in order for this toolchain to be selected during toolchain resolution.",
        ),
        "toolchain": attr.string(
            doc = "The name of the toolchain implementation target.",
            mandatory = True,
        ),
        "toolchain_type": attr.string(
            doc = "The toolchain type of the toolchain to declare",
            mandatory = True,
        ),
    },
    implementation = _toolchain_repository_proxy_impl,
)

# For legacy support
rust_toolchain_repository_proxy = toolchain_repository_proxy

# N.B. A "proxy repository" is needed to allow for registering the toolchain (with constraints)
# without actually downloading the toolchain.
def rust_toolchain_repository(
        name,
        version,
        exec_triple,
        target_triple,
        exec_compatible_with = None,
        target_compatible_with = None,
        channel = None,
        include_rustc_srcs = False,
        allocator_library = None,
        iso_date = None,
        rustfmt_version = None,
        edition = None,
        dev_components = False,
        sha256s = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        auth = None):
    """Assembles a remote repository for the given toolchain params, produces a proxy repository \
    to contain the toolchain declaration, and registers the toolchains.

    Args:
        name (str): The name of the generated repository
        version (str): The version of the tool among "nightly", "beta", or an exact version.
        exec_triple (str): The Rust-style target that this compiler runs on.
        target_triple (str): The Rust-style target to build for.
        channel (str, optional): The channel of the Rust toolchain.
        exec_compatible_with (list, optional): A list of constraints for the execution platform for this toolchain.
        target_compatible_with (list, optional): A list of constraints for the target platform for this toolchain.
        include_rustc_srcs (bool, optional): Whether to download rustc's src code. This is required in order to use rust-analyzer support.
        allocator_library (str, optional): Target that provides allocator functions when rust_library targets are embedded in a cc_binary.
        iso_date (str, optional): The date of the tool.
        rustfmt_version (str, optional):  The version of rustfmt to be associated with the
            toolchain.
        edition (str, optional): The rust edition to be used by default (2015, 2018, or 2021). If absent, every rule is required to specify its `edition` attribute.
        dev_components (bool, optional): Whether to download the rustc-dev components.
            Requires version to be "nightly". Defaults to False.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes. See
            [rust_repositories](#rust_repositories) for more details.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']
        auth (dict): Auth object compatible with repository_ctx.download to use when downloading files.
            See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.
    """

    if exec_compatible_with == None:
        exec_compatible_with = triple_to_constraint_set(exec_triple)

    if target_compatible_with == None:
        target_compatible_with = triple_to_constraint_set(target_triple)

    tools_repo_name = "{}_tools".format(name)

    rust_toolchain_tools_repository(
        name = tools_repo_name,
        exec_triple = exec_triple,
        include_rustc_srcs = include_rustc_srcs,
        allocator_library = allocator_library,
        target_triple = target_triple,
        iso_date = iso_date,
        version = version,
        rustfmt_version = rustfmt_version,
        edition = edition,
        dev_components = dev_components,
        sha256s = sha256s,
        urls = urls,
        auth = auth,
    )

    toolchain_repository_proxy(
        name = name,
        toolchain = "@{}//:rust_toolchain".format(tools_repo_name),
        target_settings = ["@rules_rust//rust/toolchain/channel:{}".format(channel)] if channel else None,
        toolchain_type = "@rules_rust//rust:toolchain",
        exec_compatible_with = exec_compatible_with,
        target_compatible_with = target_compatible_with,
    )

def _rust_analyzer_toolchain_tools_repository_impl(repository_ctx):
    load_rust_src(repository_ctx)

    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    host_triple = get_host_triple(repository_ctx)
    build_contents = [
        load_rust_compiler(
            ctx = repository_ctx,
            iso_date = repository_ctx.attr.iso_date,
            target_triple = host_triple.str,
            version = repository_ctx.attr.version,
        ),
    ]
    rustc = "//:rustc"

    proc_macro_srv = None
    if includes_rust_analyzer_proc_macro_srv(repository_ctx.attr.version, repository_ctx.attr.iso_date):
        build_contents.append(BUILD_for_rust_analyzer_proc_macro_srv(host_triple.str))
        proc_macro_srv = "//:rust_analyzer_proc_macro_srv"

    build_contents.append(BUILD_for_rust_analyzer_toolchain(
        name = "rust_analyzer_toolchain",
        rustc = rustc,
        proc_macro_srv = proc_macro_srv,
    ))

    repository_ctx.file("BUILD.bazel", "\n".join(build_contents))
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

rust_analyzer_toolchain_tools_repository = repository_rule(
    doc = "A repository rule for defining a rust_analyzer_toolchain with a `rust-src` artifact.",
    attrs = {
        "auth": attr.string_dict(
            doc = (
                "Auth object compatible with repository_ctx.download to use when downloading files. " +
                "See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details."
            ),
        ),
        "iso_date": attr.string(
            doc = "The date of the tool (or None, if the version is a specific version).",
        ),
        "sha256s": attr.string_dict(
            doc = "A dict associating tool subdirectories to sha256 hashes. See [rust_repositories](#rust_repositories) for more details.",
        ),
        "urls": attr.string_list(
            doc = "A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format).",
            default = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        ),
        "version": attr.string(
            doc = "The version of the tool among \"nightly\", \"beta\", or an exact version.",
            mandatory = True,
        ),
    },
    implementation = _rust_analyzer_toolchain_tools_repository_impl,
)

def rust_analyzer_toolchain_repository(
        name,
        version,
        exec_compatible_with = [],
        target_compatible_with = [],
        iso_date = None,
        sha256s = None,
        urls = None,
        auth = None):
    """Assemble a remote rust_analyzer_toolchain target based on the given params.

    Args:
        name (str): The name of the toolchain proxy repository contianing the registerable toolchain.
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        exec_compatible_with (list, optional): A list of constraints for the execution platform for this toolchain.
        target_compatible_with (list, optional): A list of constraints for the target platform for this toolchain.
        iso_date (str, optional): The date of the tool.
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes. See
            [rust_repositories](#rust_repositories) for more details.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These must contain the '{}' used to substitute the tool being fetched (using .format). Defaults to ['https://static.rust-lang.org/dist/{}.tar.gz']
        auth (dict): Auth object compatible with repository_ctx.download to use when downloading files.
            See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.

    Returns:
        str: The name of a registerable rust_analyzer_toolchain.
    """
    rust_analyzer_toolchain_tools_repository(
        name = name + "_tools",
        version = version,
        iso_date = iso_date,
        sha256s = sha256s,
        urls = urls,
        auth = auth,
    )

    toolchain_repository_proxy(
        name = name,
        toolchain = "@{}//:{}".format(name + "_tools", "rust_analyzer_toolchain"),
        toolchain_type = "@rules_rust//rust/rust_analyzer:toolchain_type",
        exec_compatible_with = exec_compatible_with,
        target_compatible_with = target_compatible_with,
    )

    return "@{}//:toolchain".format(
        name,
    )

def _rust_toolchain_set_repository_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    repository_ctx.file("BUILD.bazel", """exports_files(["defs.bzl"])""")
    repository_ctx.file("defs.bzl", "ALL_TOOLCHAINS = {}\n".format(
        json.encode_indent(repository_ctx.attr.toolchains, indent = " " * 4),
    ))

rust_toolchain_set_repository = repository_rule(
    doc = (
        "Generates a toolchain-bearing repository that declares the toolchains from some other " +
        "rust_toolchain_repository."
    ),
    attrs = {
        "toolchains": attr.string_list(
            doc = "The list of all toolchains created by the current `rust_toolchain_set`",
            mandatory = True,
        ),
    },
    implementation = _rust_toolchain_set_repository_impl,
)

def validate_channels(name, versions, iso_date, version):
    # Parse all provided versions while checking for duplicates
    channels = {}
    for version in versions:
        if version.startswith(("beta", "nightly")):
            channel, _, date = version.partition("/")
            ver = channel
        else:
            channel = "stable"
            date = iso_date
            ver = version

        if channel in channels:
            fail("Duplicate {} channels provided for {}: {}".format(channel, name, versions))

        channels.update({channel: struct(
            iso_date = date,
            version = ver,
        )})
    return channels

def get_toolchain_repositories(name, exec_triple, extra_target_triples, channels):
    return [
        struct(
            name = "{}__{}__{}".format(name, target_triple, channel),
            target_triple = target_triple,
            iso_date = info.iso_date,
            version = info.version,
            channel = channel,
        )
        for channel, info in channels.items()
        for target_triple in [exec_triple] + extra_target_triples
    ]

def rust_repository_set(
        name,
        exec_triple,
        version = None,
        versions = [],
        include_rustc_srcs = False,
        allocator_library = None,
        extra_target_triples = [],
        iso_date = None,
        rustfmt_version = None,
        edition = None,
        dev_components = False,
        sha256s = None,
        urls = DEFAULT_STATIC_RUST_URL_TEMPLATES,
        auth = None,
        register_toolchain = True):
    """Assembles a remote repository for the given toolchain params, produces a proxy repository \
    to contain the toolchain declaration, and registers the toolchains.

    Args:
        name (str): The name of the generated repository
        exec_triple (str): The Rust-style target that this compiler runs on
        version (str): The version of the tool among "nightly", "beta', or an exact version.
        versions (list, optional): A list of toolchain versions to download. This paramter only accepts one versions
            per channel. E.g. `["1.65.0", "nightly/2022-11-02", "beta/2020-12-30"]`.
        include_rustc_srcs (bool, optional): **Deprecated** - instead see [rust_analyzer_toolchain_repository](#rust_analyzer_toolchain_repository).
        allocator_library (str, optional): Target that provides allocator functions when rust_library targets are
            embedded in a cc_binary.
        extra_target_triples (list, optional): Additional rust-style targets that this set of
            toolchains should support.
        iso_date (str, optional): The date of the tool.
        rustfmt_version (str, optional):  The version of rustfmt to be associated with the
            toolchain.
        edition (str, optional): The rust edition to be used by default (2015, 2018, or 2021). If absent, every rule is
            required to specify its `edition` attribute.
        dev_components (bool, optional): Whether to download the rustc-dev components.
            Requires version to be "nightly".
        sha256s (str, optional): A dict associating tool subdirectories to sha256 hashes. See
            [rust_repositories](#rust_repositories) for more details.
        urls (list, optional): A list of mirror urls containing the tools from the Rust-lang static file server. These
            must contain the '{}' used to substitute the tool being fetched (using .format).
        auth (dict): Auth object compatible with repository_ctx.download to use when downloading files.
            See [repository_ctx.download](https://docs.bazel.build/versions/main/skylark/lib/repository_ctx.html#download) for more details.
        register_toolchain (bool): If True, the generated `rust_toolchain` target will become a registered toolchain.
    """

    if include_rustc_srcs:
        # buildifier: disable=print
        print("include_rustc_srcs is deprecated. Instead see https://bazelbuild.github.io/rules_rust/flatten.html#rust_analyzer_toolchain_repository")

    if version and versions:
        fail("`version` and `versions` attributes are mutually exclusive. Update {} to use one".format(
            name,
        ))

    if not version and not versions:
        fail("`version` or `versions` attributes are required. Update {} to use one".format(
            name,
        ))

    if version and not versions:
        versions = [version]

    channels = validate_channels(name, versions, iso_date, versions)

    all_toolchain_names = []
    for toolchain in get_toolchain_repositories(name, exec_triple, extra_target_triples, channels):
        rust_toolchain_repository(
            name = toolchain.name,
            allocator_library = allocator_library,
            auth = auth,
            channel = toolchain.channel,
            dev_components = dev_components,
            edition = edition,
            exec_triple = exec_triple,
            include_rustc_srcs = include_rustc_srcs,
            iso_date = toolchain.iso_date,
            rustfmt_version = rustfmt_version,
            sha256s = sha256s,
            target_triple = toolchain.target_triple,
            urls = urls,
            version = toolchain.version,
        )

        all_toolchain_names.append("@{name}//:toolchain".format(name = toolchain.name))

    # This repository exists to allow `rust_repository_set` to work with the `maybe` wrapper.
    rust_toolchain_set_repository(
        name = name,
        toolchains = all_toolchain_names,
    )

    # Register toolchains
    if register_toolchain:
        native.register_toolchains(*all_toolchain_names)
        native.register_toolchains(str(Label("//rust/private/dummy_cc_toolchain:dummy_cc_wasm32_toolchain")))
