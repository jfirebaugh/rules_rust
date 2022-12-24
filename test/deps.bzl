"""A module defining dependencies of the `rules_rust` tests"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//test/load_arbitrary_tool:load_arbitrary_tool_test.bzl", "load_arbitrary_tool_test")

_LIBC_BUILD_FILE_CONTENT = """\
load("@rules_rust//rust:defs.bzl", "rust_library")

rust_library(
    name = "libc",
    srcs = glob(["src/**/*.rs"]),
    edition = "2015",
    rustc_flags = [
        # In most cases, warnings in 3rd party crates are not interesting as
        # they're out of the control of consumers. The flag here silences
        # warnings. For more details see:
        # https://doc.rust-lang.org/rustc/lints/levels.html
        "--cap-lints=allow",
    ],
    visibility = ["//visibility:public"],
)
"""

def rules_rust_test_deps():
    """Load dependencies for rules_rust tests"""

    load_arbitrary_tool_test()

    maybe(
        http_archive,
        name = "libc",
        build_file_content = _LIBC_BUILD_FILE_CONTENT,
        sha256 = "1ac4c2ac6ed5a8fb9020c166bc63316205f1dc78d4b964ad31f4f21eb73f0c6d",
        strip_prefix = "libc-0.2.20",
        urls = [
            "https://mirror.bazel.build/github.com/rust-lang/libc/archive/0.2.20.zip",
            "https://github.com/rust-lang/libc/archive/0.2.20.zip",
        ],
    )

    http_archive(
        name = "contrib_rules_bazel_integration_test",
        patch_args = ["-p1"],
        patches = ["@//test:0001-Add-support-for-WORKSPACE.bazel.patch"],
        sha256 = "20d670bb614d311a2a0fc8af53760439214731c3d5be2d9b0a197dccc19583f5",
        strip_prefix = "rules_bazel_integration_test-0.9.0",
        urls = [
            "http://github.com/bazel-contrib/rules_bazel_integration_test/archive/v0.9.0.tar.gz",
        ],
    )
