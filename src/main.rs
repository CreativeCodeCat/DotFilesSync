//! hyprsync: keep ~/.config/{hypr,quickshell} and the HyprSync folder in step.
//!
//!   hyprsync pull    copy ~/.config folders into the project
//!   hyprsync push    copy project folders back into ~/.config
//!   hyprsync watch   keep the project up to date with ~/.config as it changes

mod sync;

use std::env;
use std::io;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::thread;
use std::time::Duration;

use sync::{Change, Kind, FOLDERS};

const USAGE: &str = "\
hyprsync: mirror ~/.config/{hypr,quickshell} with the HyprSync folder

USAGE:
    hyprsync pull [--dry-run]            copy ~/.config folders into the project
    hyprsync push [--dry-run]            copy project folders into ~/.config
    hyprsync watch [--interval SECS]     pull whenever ~/.config changes (default 2s)
    hyprsync help                        show this message

pull and push mirror: anything missing on the receiving side is added,
anything changed is overwritten, and anything no longer in the source is
removed. --dry-run (or -n) prints the changes without making them.

watch only pulls. It never writes to ~/.config, so a live edit there can't
be overwritten by accident. Stop it with Ctrl-C.

ENVIRONMENT:
    HYPRSYNC_DIR      project folder (default: ~/HyprSync)
    HYPRSYNC_CONFIG   config folder  (default: ~/.config)
";

#[derive(Clone, Copy)]
enum Direction {
    Pull,
    Push,
}

fn main() -> ExitCode {
    let args: Vec<String> = env::args().skip(1).collect();

    if args.iter().any(|a| a == "-h" || a == "--help") {
        print!("{USAGE}");
        return ExitCode::SUCCESS;
    }

    let dry_run = args.iter().any(|a| a == "-n" || a == "--dry-run");
    let command = args.iter().find(|a| !a.starts_with('-')).map(String::as_str);

    let result = match command {
        Some("pull") => run(Direction::Pull, dry_run),
        Some("push") => run(Direction::Push, dry_run),
        Some("watch") => match parse_interval(&args) {
            Ok(interval) => watch(interval),
            Err(msg) => {
                eprintln!("hyprsync: {msg}");
                return ExitCode::from(2);
            }
        },
        Some("help") | None => {
            print!("{USAGE}");
            return ExitCode::SUCCESS;
        }
        Some(other) => {
            eprintln!("hyprsync: unknown command '{other}'\n");
            eprint!("{USAGE}");
            return ExitCode::from(2);
        }
    };

    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("hyprsync: {e}");
            ExitCode::FAILURE
        }
    }
}

/// Read `--interval SECS` (or `--interval=SECS`). Defaults to 2 seconds.
fn parse_interval(args: &[String]) -> Result<Duration, String> {
    let mut value = None;
    let mut iter = args.iter();
    while let Some(arg) = iter.next() {
        if let Some(v) = arg.strip_prefix("--interval=") {
            value = Some(v.to_string());
        } else if arg == "--interval" {
            value = Some(iter.next().ok_or("--interval needs a value")?.clone());
        }
    }
    match value {
        None => Ok(Duration::from_secs(2)),
        Some(v) => match v.parse::<f64>() {
            Ok(secs) if secs >= 0.5 && secs.is_finite() => Ok(Duration::from_secs_f64(secs)),
            _ => Err(format!("--interval must be a number of seconds, at least 0.5 (got '{v}')")),
        },
    }
}

fn run(direction: Direction, dry_run: bool) -> io::Result<()> {
    let config = config_dir()?;
    let project = project_dir()?;

    // Plan every folder before touching anything, so a problem with one
    // folder stops the whole run instead of leaving a half-done sync.
    let mut jobs = Vec::new();
    for folder in FOLDERS {
        let (src, dst) = endpoints(direction, &config, &project, folder);
        let changes = sync::plan(&src, &dst)?;
        jobs.push((*folder, src, dst, changes));
    }

    let verb = match direction {
        Direction::Pull => "pull",
        Direction::Push => "push",
    };
    let mut totals = [0usize; 3];

    for (folder, src, dst, changes) in &jobs {
        println!("{folder}: {} -> {}", src.display(), dst.display());
        if changes.is_empty() {
            println!("  up to date");
            continue;
        }
        for change in changes {
            println!("  {} {}", symbol(change), change.rel.display());
            match change.kind {
                Kind::Add => totals[0] += 1,
                Kind::Update => totals[1] += 1,
                Kind::Remove => totals[2] += 1,
            }
        }
        if !dry_run {
            sync::apply(src, dst, changes)?;
        }
    }

    let [added, updated, removed] = totals;
    let action = if dry_run { "would change" } else { "changed" };
    println!(
        "\n{verb}: {action} {added} added, {updated} updated, {removed} removed"
    );
    Ok(())
}

/// Poll ~/.config and pull changes into the project until interrupted.
///
/// Errors from a single pass are printed and the loop carries on. Editors
/// often save by replacing a file, so a pass can catch a folder half-written.
fn watch(interval: Duration) -> io::Result<()> {
    let config = config_dir()?;
    let project = project_dir()?;
    println!(
        "watching {} every {}s (Ctrl-C to stop)",
        FOLDERS.iter().map(|f| config.join(f).display().to_string()).collect::<Vec<_>>().join(", "),
        interval.as_secs_f64()
    );

    loop {
        if let Err(e) = pull_changes(&config, &project) {
            eprintln!("hyprsync: {e}");
        }
        thread::sleep(interval);
    }
}

/// One watch pass: pull any folder that differs, and print only what changed.
fn pull_changes(config: &Path, project: &Path) -> io::Result<()> {
    for folder in FOLDERS {
        let (src, dst) = endpoints(Direction::Pull, config, project, folder);
        let changes = sync::plan(&src, &dst)?;
        if changes.is_empty() {
            continue;
        }
        println!("{folder}:");
        for change in &changes {
            println!("  {} {}", symbol(change), change.rel.display());
        }
        sync::apply(&src, &dst, &changes)?;
    }
    Ok(())
}

/// Source and destination for one folder in one direction.
fn endpoints(direction: Direction, config: &Path, project: &Path, folder: &str) -> (PathBuf, PathBuf) {
    let in_config = config.join(folder);
    let in_project = project.join(folder);
    match direction {
        Direction::Pull => (in_config, in_project),
        Direction::Push => (in_project, in_config),
    }
}

fn symbol(change: &Change) -> char {
    match change.kind {
        Kind::Add => '+',
        Kind::Update => '~',
        Kind::Remove => '-',
    }
}

fn home() -> io::Result<PathBuf> {
    env::var_os("HOME")
        .map(PathBuf::from)
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "HOME is not set"))
}

fn config_dir() -> io::Result<PathBuf> {
    match env::var_os("HYPRSYNC_CONFIG") {
        Some(p) => Ok(PathBuf::from(p)),
        None => Ok(home()?.join(".config")),
    }
}

fn project_dir() -> io::Result<PathBuf> {
    match env::var_os("HYPRSYNC_DIR") {
        Some(p) => Ok(PathBuf::from(p)),
        None => Ok(home()?.join("HyprSync")),
    }
}
