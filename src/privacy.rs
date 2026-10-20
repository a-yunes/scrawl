//! Privacy boundaries for local storage and optional diagnostics.

/// Apply before creating files or starting workers. New files are owner-only, including
/// recordings written by the helper process, which inherits this mask.
pub fn initialize() {
    #[cfg(unix)]
    unsafe {
        libc::umask(0o077);
    }
}

pub fn diagnostics_enabled() -> bool {
    std::env::var_os("SCRAWL_DIAGNOSTICS").is_some_and(|v| v == "1")
}

/// Copy bytes without inheriting a source file's public permissions.
pub fn copy_private(
    source: impl AsRef<std::path::Path>,
    destination: impl AsRef<std::path::Path>,
) -> std::io::Result<u64> {
    use std::fs::{File, OpenOptions};
    use std::os::unix::fs::{MetadataExt, OpenOptionsExt, PermissionsExt};
    let mut input = File::open(source)?;
    let input_meta = input.metadata()?;
    if !input_meta.is_file() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "capture source is not a regular file",
        ));
    }
    let mut output = OpenOptions::new()
        .write(true)
        .create(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW)
        .open(destination)?;
    let output_meta = output.metadata()?;
    if input_meta.dev() == output_meta.dev() && input_meta.ino() == output_meta.ino() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "capture source and destination refer to the same file",
        ));
    }
    output.set_permissions(std::fs::Permissions::from_mode(0o600))?;
    output.set_len(0)?;
    std::io::copy(&mut input, &mut output)
}

/// Diagnostic messages must not preserve URL capabilities, credentials or query values.
/// Remove the whole URL, including custom schemes, rather than trying to enumerate secrets.
pub fn redact_urls(message: &str) -> String {
    message
        .split_inclusive(char::is_whitespace)
        .map(|word| {
            if word.contains("://") {
                let trailing = &word[word.trim_end().len()..];
                format!("[redacted URL]{trailing}")
            } else {
                word.to_owned()
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn diagnostics_remove_url_credentials_queries_fragments_and_custom_schemes() {
        let message = "failed HTTPS://user:password@example.test/invite/key?token=SECRET#code=OTHER\n\
                       link=app://scrawl?token=THIRD file:///Users/person/private.txt";
        let redacted = redact_urls(message);
        for secret in ["password", "SECRET", "OTHER", "THIRD", "private.txt", "example.test"] {
            assert!(!redacted.contains(secret), "{redacted}");
        }
        assert_eq!(redacted.matches("[redacted URL]").count(), 3);
        assert!(redacted.contains('\n'));
    }

    #[test]
    fn ordinary_diagnostics_keep_their_spacing() {
        let message = "capture finished: 12 frames\n  processing took 40 ms";
        assert_eq!(redact_urls(message), message);
    }

    #[test]
    fn copied_media_is_private_and_never_follows_destination_symlinks() {
        use std::os::unix::fs::{PermissionsExt, symlink};
        let dir = std::env::temp_dir().join(format!(
            "scrawl-copy-{}-{}",
            std::process::id(),
            crate::now_epoch_ms()
        ));
        std::fs::create_dir(&dir).unwrap();
        let source = dir.join("source");
        let destination = dir.join("destination");
        std::fs::write(&source, b"private recording").unwrap();
        std::fs::set_permissions(&source, std::fs::Permissions::from_mode(0o644)).unwrap();
        copy_private(&source, &destination).unwrap();
        assert_eq!(std::fs::read(&destination).unwrap(), b"private recording");
        assert_eq!(std::fs::metadata(&destination).unwrap().permissions().mode() & 0o777, 0o600);
        assert!(copy_private(&source, &source).is_err());
        let link = dir.join("link");
        symlink(&source, &link).unwrap();
        assert!(copy_private(&destination, &link).is_err());
        assert_eq!(std::fs::read(&source).unwrap(), b"private recording");
        std::fs::remove_dir_all(dir).unwrap();
    }
}
