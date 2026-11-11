//! hyprsync: keep ~/.config/{hypr,quickshell} and the HyprSync folder in step.
//!
//!   hyprsync pull   copy ~/.config folders into the project
//!   hyprsync push   copy project folders back into ~/.config

mod sync;

use std::env;
use std::io;
use std::path::PathBuf;
use std::process::ExitCode;

use sync::{Change, Kind, FOLDERS};

const USAGE: &str = "\
hyprsync: mirror ~/.config/{hypr,quickshell} with the HyprSync folder

USAGE:
    hyprsync pull [--dry-run]   copy ~/.config folders into the project
    hyprsync push [--dry-run]   copy project folders into ~/.config
    hyprsync help               show this message

Both directions mirror: anything missing on the receiving side is added,
anything changed is overwritten, and anything no longer in the source is
removed. --dry-run (or -n) prints the changes without making them.

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

    let direction = match command {
        Some("pull") => Direction::Pull,
        Some("push") => Direction::Push,
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

    match run(direction, dry_run) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("hyprsync: {e}");
            ExitCode::FAILURE
        }
    }
}

fn run(direction: Direction, dry_run: bool) -> io::Result<()> {
    let config = config_dir()?;
    let project = project_dir()?;

    // Plan every folder before touching anything, so a problem with one
    // folder stops the whole run instead of leaving a half-done sync.
    let mut jobs = Vec::new();
    for folder in FOLDERS {
        let in_config = config.join(folder);
        let in_project = project.join(folder);
        let (src, dst) = match direction {
            Direction::Pull => (in_config, in_project),
            Direction::Push => (in_project, in_config),
        };
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
