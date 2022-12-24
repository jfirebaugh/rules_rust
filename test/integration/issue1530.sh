set -euo pipefail
cd "$BIT_WORKSPACE_DIR"
"$BIT_BAZEL_BINARY" build --execution_log_json_file=build-1.json //:panic
"$BIT_BAZEL_BINARY" clean
"$BIT_BAZEL_BINARY" build --execution_log_json_file=build-2.json //:panic
diff -u -I walltime build-1.json build-2.json
