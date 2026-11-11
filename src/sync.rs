//! Mirror one folder tree onto another.
//!
//! `plan` compares the two trees and lists what has to change. `apply`
//! carries those changes out. Mirroring means the destination ends up
//! identical to the source, so files that no longer exist in the source are
//! removed from the destination.

use std::collections::BTreeSet;
use std::fs;
use std::io::{self, ErrorKind};
use std::os::unix::fs::{symlink, PermissionsExt};
use std::path::{Path, PathBuf};

/// Names skipped at any depth, on both sides.
const IGNORED: &[&str] = &[".git", "__pycache__", ".DS_Store"];

#[derive(Debug, PartialEq)]
enum Node {
    Dir,
    File { mode: u32, data: Vec<u8> },
    Link(PathBuf),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Add,
    Update,
    Remove,
}

#[derive(Debug)]
pub struct Change {
    pub kind: Kind,
    pub rel: PathBuf,
}

/// Work out what has to change in `dst` to make it match `src`.
///
/// Fails if `src` is missing, or if it is empty while `dst` has content.
/// The second check stops an empty source from wiping the destination.
pub fn plan(src: &Path, dst: &Path) -> io::Result<Vec<Change>> {
    if !src.is_dir() {
        return Err(io::Error::new(
            ErrorKind::NotFound,
            format!("source folder not found: {}", src.display()),
        ));
    }

    let want = list(src)?;
    let have = if dst.is_dir() { list(dst)? } else { BTreeSet::new() };

    if want.is_empty() && !have.is_empty() {
        return Err(io::Error::other(format!(
            "refusing to empty {} because {} has no files",
            dst.display(),
            src.display()
        )));
    }

    let mut changes = Vec::new();

    // BTreeSet order puts a parent directory before its children,
    // so directories are created before the files inside them.
    for rel in &want {
        if !have.contains(rel) {
            changes.push(Change { kind: Kind::Add, rel: rel.clone() });
        } else if read_node(&src.join(rel))? != read_node(&dst.join(rel))? {
            changes.push(Change { kind: Kind::Update, rel: rel.clone() });
        }
    }

    // Reverse order removes children before their parent directories.
    for rel in have.iter().rev() {
        if !want.contains(rel) {
            changes.push(Change { kind: Kind::Remove, rel: rel.clone() });
        }
    }

    Ok(changes)
}

/// Apply the changes from `plan` to `dst`.
pub fn apply(src: &Path, dst: &Path, changes: &[Change]) -> io::Result<()> {
    for change in changes {
        let target = dst.join(&change.rel);
        match change.kind {
            Kind::Remove => remove_path(&target)?,
            Kind::Add => write_node(&src.join(&change.rel), &target)?,
            Kind::Update => {
                // The entry may change type (file to dir, say), so clear it first.
                remove_path(&target)?;
                write_node(&src.join(&change.rel), &target)?;
            }
        }
    }
    Ok(())
}

/// Every path under `root`, relative to it, skipping ignored names.
/// Symlinks are listed but not followed.
fn list(root: &Path) -> io::Result<BTreeSet<PathBuf>> {
    let mut out = BTreeSet::new();
    let mut stack = vec![PathBuf::new()];

    while let Some(rel) = stack.pop() {
        for entry in fs::read_dir(root.join(&rel))? {
            let entry = entry?;
            let name = entry.file_name();
            if name.to_str().is_some_and(|n| IGNORED.contains(&n)) {
                continue;
            }
            let child = rel.join(&name);
            if entry.file_type()?.is_dir() {
                stack.push(child.clone());
            }
            out.insert(child);
        }
    }

    Ok(out)
}

/// Read a path without following symlinks.
fn read_node(path: &Path) -> io::Result<Node> {
    let meta = fs::symlink_metadata(path)?;
    let ft = meta.file_type();
    if ft.is_symlink() {
        Ok(Node::Link(fs::read_link(path)?))
    } else if ft.is_dir() {
        Ok(Node::Dir)
    } else {
        Ok(Node::File {
            mode: meta.permissions().mode() & 0o777,
            data: fs::read(path)?,
        })
    }
}

/// Create `dst` as a copy of `src`, keeping permissions and symlinks.
fn write_node(src: &Path, dst: &Path) -> io::Result<()> {
    if let Some(parent) = dst.parent() {
        fs::create_dir_all(parent)?;
    }
    match read_node(src)? {
        Node::Dir => fs::create_dir_all(dst),
        Node::File { mode, data } => {
            fs::write(dst, data)?;
            fs::set_permissions(dst, fs::Permissions::from_mode(mode))
        }
        Node::Link(target) => symlink(target, dst),
    }
}

/// Remove a file, link or directory tree. A missing path is not an error.
fn remove_path(path: &Path) -> io::Result<()> {
    match fs::symlink_metadata(path) {
        Ok(meta) if meta.is_dir() => fs::remove_dir_all(path),
        Ok(_) => fs::remove_file(path),
        Err(e) if e.kind() == ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e),
    }
}
