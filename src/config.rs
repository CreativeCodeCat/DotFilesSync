//! Reads `config.lua`, which lists the folders under the config root to sync.
//!
//! The file is ordinary Lua that returns a table:
//!
//! ```lua
//! return {
//!     folders = { "hypr", "quickshell" },
//! }
//! ```
//!
//! The file is required. There is no built-in list of folders.

use std::fs;
use std::io::{self, ErrorKind};
use std::path::Path;

use mlua::{Lua, Table, Value};

/// Load the folder list from `path`. The file must exist.
pub fn load(path: &Path) -> io::Result<Vec<String>> {
    if !path.is_file() {
        return Err(io::Error::new(
            ErrorKind::NotFound,
            format!(
                "no config at {}; create it with: return {{ folders = {{ \"hypr\", \"quickshell\" }} }}",
                path.display()
            ),
        ));
    }

    let source = fs::read_to_string(path)?;
    let invalid =
        |msg: String| io::Error::new(ErrorKind::InvalidData, format!("{}: {msg}", path.display()));

    let lua = Lua::new();
    let value: Value = lua
        .load(&source)
        .set_name(path.display().to_string())
        .eval()
        .map_err(|e| invalid(e.to_string()))?;

    let Value::Table(table) = value else {
        return Err(invalid(
            "config must return a table, e.g. return { folders = { \"hypr\" } }".into(),
        ));
    };

    let folders = folders_from(&table).map_err(|e| invalid(e.to_string()))?;
    let folders = folders.ok_or_else(|| invalid("config is missing 'folders'".into()))?;

    let mut names: Vec<String> = Vec::new();
    for name in folders {
        validate(&name).map_err(invalid)?;
        if names.contains(&name) {
            return Err(invalid(format!("folder '{name}' is listed twice")));
        }
        names.push(name);
    }

    if names.is_empty() {
        return Err(invalid(
            "'folders' is empty; list at least one folder".into(),
        ));
    }
    Ok(names)
}

/// The `folders` entry as a list of names, or `None` if it is not set.
fn folders_from(table: &Table) -> mlua::Result<Option<Vec<String>>> {
    match table.get::<Value>("folders")? {
        Value::Nil => Ok(None),
        Value::Table(list) => list
            .sequence_values::<String>()
            .collect::<mlua::Result<Vec<_>>>()
            .map(Some),
        _ => Err(mlua::Error::runtime("'folders' must be a list of strings")),
    }
}

/// A folder name must be a single plain name directly under the config root.
fn validate(name: &str) -> Result<(), String> {
    if name.is_empty() || name == "." || name == ".." || name.contains('/') || name.contains('\0') {
        return Err(format!(
            "'{name}' is not a valid folder name (use a name directly under the config folder)"
        ));
    }
    Ok(())
}
