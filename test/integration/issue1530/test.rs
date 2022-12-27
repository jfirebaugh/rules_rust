use integration::{bazel, workspace_path};
use similar::{ChangeTag, TextDiff};

#[test]
fn test_issue_1530() -> Result<(), std::io::Error> {
    std::env::set_current_dir(workspace_path())?;

    bazel("build")
        .args(["--execution_log_json_file=build-a.json", "//:panic"])
        .status()?;
    bazel("clean").status()?;
    bazel("build")
        .args(["--execution_log_json_file=build-b.json", "//:panic"])
        .status()?;

    let a = std::fs::read_to_string("build-a.json")?;
    let b = std::fs::read_to_string("build-b.json")?;
    let diff = TextDiff::from_lines(&a, &b);
    if !diff
        .iter_all_changes()
        .all(|change| change.tag() == ChangeTag::Equal || change.value().contains("walltime"))
    {
        print!(
            "{}",
            diff.unified_diff().context_radius(10).header("a", "b")
        );
        panic!("non-deterministic build detected");
    }
    Ok(())
}
