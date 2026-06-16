use std::fs;

use zed_extension_api::{
    self as zed, settings::LspSettings, Architecture, Command, DownloadedFileType,
    LanguageServerId, LanguageServerInstallationStatus, Os, Result, Worktree,
};

const LSP_BINARY_NAME: &str = "lexd-lsp";

/// Pinned versions for the LSP binary and tree-sitter grammar.
///
/// Mirrors the convention shared with the vscode and nvim editor packages:
/// `shared/lex-deps.json` is the single source of truth, embedded at compile
/// time. Bumping the LSP version is a one-file change.
#[derive(serde::Deserialize)]
struct LexDeps {
    #[serde(rename = "lexd-lsp")]
    lexd_lsp: String,
    #[serde(rename = "lexd-lsp-repo")]
    lexd_lsp_repo: String,
}

const LEX_DEPS_JSON: &str = include_str!("../shared/lex-deps.json");

fn lex_deps() -> Result<LexDeps> {
    serde_json::from_str(LEX_DEPS_JSON)
        .map_err(|e| format!("failed to parse shared/lex-deps.json: {e}"))
}

/// GitHub release asset name for the current platform.
///
/// Matches the artifacts produced by lex-fmt/lex's release.yml. Windows
/// arm64 is not built upstream and falls back to amd64 (handled by the
/// Architecture::Aarch64 case for Windows below — Zed runs the WASM
/// extension on the host arch, so a Windows arm64 user would get an
/// amd64 binary running under emulation).
fn asset_filename(os: Os, arch: Architecture) -> Result<&'static str> {
    Ok(match (os, arch) {
        (Os::Linux, Architecture::X8664) => "lexd-lsp-x86_64-unknown-linux-gnu.tar.gz",
        (Os::Linux, Architecture::Aarch64) => "lexd-lsp-aarch64-unknown-linux-gnu.tar.gz",
        (Os::Mac, Architecture::X8664) => "lexd-lsp-x86_64-apple-darwin.tar.gz",
        (Os::Mac, Architecture::Aarch64) => "lexd-lsp-aarch64-apple-darwin.tar.gz",
        (Os::Windows, _) => "lexd-lsp-x86_64-pc-windows-msvc.zip",
        (os, arch) => {
            return Err(format!(
                "no prebuilt lexd-lsp binary for {os:?}/{arch:?}; \
                 set lsp.lex-lsp.binary.path in settings.json to point at a local build"
            ))
        }
    })
}

fn binary_filename(os: Os) -> &'static str {
    match os {
        Os::Windows => "lexd-lsp.exe",
        _ => "lexd-lsp",
    }
}

fn archive_kind(os: Os) -> DownloadedFileType {
    match os {
        Os::Windows => DownloadedFileType::Zip,
        _ => DownloadedFileType::GzipTar,
    }
}

struct LexExtension {
    cached_binary_path: Option<String>,
}

impl LexExtension {
    /// Resolve the lexd-lsp binary path. Order:
    /// 1. User-configured `lsp.lex-lsp.binary.path` in settings.json
    /// 2. `lexd-lsp` on `$PATH` (developer override)
    /// 3. Cached extension download for the pinned version
    /// 4. Fresh download from GitHub releases
    fn resolve_binary(
        &mut self,
        server_id: &LanguageServerId,
        worktree: &Worktree,
    ) -> Result<String> {
        if let Some(path) = LspSettings::for_worktree(server_id.as_ref(), worktree)
            .ok()
            .and_then(|s| s.binary)
            .and_then(|b| b.path)
        {
            return Ok(path);
        }

        if let Some(path) = worktree.which(LSP_BINARY_NAME) {
            return Ok(path);
        }

        if let Some(path) = self.cached_binary_path.as_ref() {
            if fs::metadata(path).is_ok_and(|m| m.is_file()) {
                return Ok(path.clone());
            }
        }

        let deps = lex_deps()?;
        let path = self.download_binary(server_id, &deps)?;
        self.cached_binary_path = Some(path.clone());
        Ok(path)
    }

    fn download_binary(&self, server_id: &LanguageServerId, deps: &LexDeps) -> Result<String> {
        let (os, arch) = zed::current_platform();
        let asset_name = asset_filename(os, arch)?;

        zed::set_language_server_installation_status(
            server_id,
            &LanguageServerInstallationStatus::CheckingForUpdate,
        );

        let release = zed::github_release_by_tag_name(&deps.lexd_lsp_repo, &deps.lexd_lsp)
            .map_err(|e| {
                format!(
                    "failed to fetch lexd-lsp release {tag} from {repo}: {e}",
                    tag = deps.lexd_lsp,
                    repo = deps.lexd_lsp_repo,
                )
            })?;

        let asset = release
            .assets
            .iter()
            .find(|a| a.name == asset_name)
            .ok_or_else(|| {
                format!(
                    "no asset named {asset_name} in lexd-lsp release {tag}",
                    tag = release.version,
                )
            })?;

        let version_dir = format!("lexd-lsp-{}", release.version);
        let binary_path = format!("{version_dir}/{}", binary_filename(os));

        if !fs::metadata(&binary_path).is_ok_and(|m| m.is_file()) {
            zed::set_language_server_installation_status(
                server_id,
                &LanguageServerInstallationStatus::Downloading,
            );
            zed::download_file(&asset.download_url, &version_dir, archive_kind(os))
                .map_err(|e| format!("failed to download {asset_name}: {e}"))?;
            if !matches!(os, Os::Windows) {
                zed::make_file_executable(&binary_path)?;
            }
            prune_old_versions(&version_dir);
        }

        Ok(binary_path)
    }
}

/// Remove cached lexd-lsp-* directories that don't match the version we just
/// installed. Best-effort: failures are ignored to avoid blocking startup.
fn prune_old_versions(keep: &str) {
    let Ok(entries) = fs::read_dir(".") else {
        return;
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        let Some(name) = name.to_str() else { continue };
        if name.starts_with("lexd-lsp-") && name != keep {
            let _ = fs::remove_dir_all(entry.path());
        }
    }
}

impl zed::Extension for LexExtension {
    fn new() -> Self {
        Self {
            cached_binary_path: None,
        }
    }

    fn language_server_command(
        &mut self,
        server_id: &LanguageServerId,
        worktree: &Worktree,
    ) -> Result<Command> {
        let path = self.resolve_binary(server_id, worktree)?;
        Ok(Command {
            command: path,
            args: vec![],
            env: vec![],
        })
    }

    fn language_server_initialization_options(
        &mut self,
        server_id: &LanguageServerId,
        worktree: &Worktree,
    ) -> Result<Option<serde_json::Value>> {
        Ok(LspSettings::for_worktree(server_id.as_ref(), worktree)
            .ok()
            .and_then(|s| s.initialization_options.clone()))
    }

    fn language_server_workspace_configuration(
        &mut self,
        server_id: &LanguageServerId,
        worktree: &Worktree,
    ) -> Result<Option<serde_json::Value>> {
        Ok(LspSettings::for_worktree(server_id.as_ref(), worktree)
            .ok()
            .and_then(|s| s.settings.clone()))
    }
}

zed::register_extension!(LexExtension);

#[cfg(test)]
mod tests {
    //! Unit tests for the pure helpers that drive lexd-lsp asset selection.
    //!
    //! These functions are the load-bearing pieces of the extension: a wrong
    //! mapping means a Zed user on that platform either fails to install or
    //! tries to execute the wrong binary. They have no host dependencies, so
    //! they run natively under `cargo test` despite the crate being a cdylib.
    use super::*;
    use serde_json::Value;
    use std::fs;
    use std::path::{Path, PathBuf};
    use std::sync::{Mutex, MutexGuard};
    use zed_extension_api::{Architecture, DownloadedFileType, Os};

    /// Serialises any test that mutates the process CWD. `cargo test` runs
    /// tests on a thread pool, and `std::env::set_current_dir` is global —
    /// without this, two CWD-touching tests race and either see the wrong
    /// directory (cross-talk) or fail spuriously (relative reads).
    static CWD_MUTEX: Mutex<()> = Mutex::new(());

    /// RAII guard: hold the CWD lock, restore the previous CWD on drop —
    /// even on panic. Without this, a panic between `set_current_dir` and
    /// the manual restore would leave later tests in the wrong directory.
    struct CwdGuard {
        prev: PathBuf,
        _lock: MutexGuard<'static, ()>,
    }

    impl CwdGuard {
        fn chdir(target: &Path) -> Self {
            // Recover from a poisoned mutex: a prior panic that left the
            // CWD unrestored is exactly the state we want to remediate
            // anyway, so unwrapping `into_inner` here is the right move.
            let lock = CWD_MUTEX.lock().unwrap_or_else(|p| p.into_inner());
            let prev = std::env::current_dir().expect("current_dir must succeed");
            std::env::set_current_dir(target).expect("set_current_dir must succeed");
            Self { prev, _lock: lock }
        }
    }

    impl Drop for CwdGuard {
        fn drop(&mut self) {
            // Best-effort restore: don't double-panic in destructor.
            let _ = std::env::set_current_dir(&self.prev);
        }
    }

    #[test]
    fn asset_filename_covers_all_built_platforms() {
        let cases: &[(Os, Architecture, &str)] = &[
            (
                Os::Linux,
                Architecture::X8664,
                "lexd-lsp-x86_64-unknown-linux-gnu.tar.gz",
            ),
            (
                Os::Linux,
                Architecture::Aarch64,
                "lexd-lsp-aarch64-unknown-linux-gnu.tar.gz",
            ),
            (
                Os::Mac,
                Architecture::X8664,
                "lexd-lsp-x86_64-apple-darwin.tar.gz",
            ),
            (
                Os::Mac,
                Architecture::Aarch64,
                "lexd-lsp-aarch64-apple-darwin.tar.gz",
            ),
            (
                Os::Windows,
                Architecture::X8664,
                "lexd-lsp-x86_64-pc-windows-msvc.zip",
            ),
        ];
        for (os, arch, want) in cases {
            let got = asset_filename(*os, *arch).expect("supported platform");
            assert_eq!(got, *want, "wrong asset for {os:?}/{arch:?}");
        }
    }

    #[test]
    fn asset_filename_windows_arm64_falls_back_to_amd64() {
        // Documented behaviour: Windows on aarch64 has no upstream build, so
        // the wildcard match deliberately serves the x86_64 binary (runs
        // under emulation). If a real Windows-arm asset is ever published,
        // update this test alongside the mapping.
        let got = asset_filename(Os::Windows, Architecture::Aarch64).unwrap();
        assert_eq!(got, "lexd-lsp-x86_64-pc-windows-msvc.zip");
    }

    #[test]
    fn asset_filename_errors_for_unsupported_arch() {
        let err = asset_filename(Os::Linux, Architecture::X86).expect_err("no 32-bit linux build");
        assert!(
            err.contains("no prebuilt lexd-lsp binary"),
            "error should explain the failure, got: {err}",
        );
        assert!(
            err.contains("lsp.lex-lsp.binary.path"),
            "error should point at the settings escape hatch, got: {err}",
        );
    }

    #[test]
    fn binary_filename_adds_exe_on_windows_only() {
        assert_eq!(binary_filename(Os::Windows), "lexd-lsp.exe");
        assert_eq!(binary_filename(Os::Mac), "lexd-lsp");
        assert_eq!(binary_filename(Os::Linux), "lexd-lsp");
    }

    #[test]
    fn archive_kind_matches_os() {
        assert!(matches!(archive_kind(Os::Windows), DownloadedFileType::Zip));
        assert!(matches!(archive_kind(Os::Mac), DownloadedFileType::GzipTar));
        assert!(matches!(
            archive_kind(Os::Linux),
            DownloadedFileType::GzipTar
        ));
    }

    #[test]
    fn archive_kind_agrees_with_asset_filename_extension() {
        // Defensive: if someone changes one mapping without the other, the
        // download silently uses the wrong unpacker. Lock the two together.
        let pairs: &[(Os, Architecture)] = &[
            (Os::Linux, Architecture::X8664),
            (Os::Linux, Architecture::Aarch64),
            (Os::Mac, Architecture::X8664),
            (Os::Mac, Architecture::Aarch64),
            (Os::Windows, Architecture::X8664),
        ];
        for (os, arch) in pairs {
            let name = asset_filename(*os, *arch).unwrap();
            match archive_kind(*os) {
                DownloadedFileType::Zip => assert!(
                    name.ends_with(".zip"),
                    "{os:?} declared Zip but asset is {name}",
                ),
                DownloadedFileType::GzipTar => assert!(
                    name.ends_with(".tar.gz"),
                    "{os:?} declared GzipTar but asset is {name}",
                ),
                // Any future archive variant should be wired in explicitly.
                other => panic!("unhandled archive kind {other:?} for {os:?}"),
            }
        }
    }

    #[test]
    fn lex_deps_parses_embedded_json() {
        let deps = lex_deps().expect("embedded lex-deps.json must parse");
        assert!(
            deps.lexd_lsp.starts_with('v'),
            "lexd-lsp pin should be a release tag like v0.8.8, got {}",
            deps.lexd_lsp,
        );
        assert!(
            deps.lexd_lsp_repo.contains('/'),
            "lexd-lsp-repo should be owner/name, got {}",
            deps.lexd_lsp_repo,
        );
    }

    #[test]
    fn lex_deps_json_is_in_sync_with_disk() {
        // The constant is `include_str!`'d at compile time, so a stale build
        // can mask drift. CI always builds fresh, so this test still catches
        // an unintended edit that didn't go through a rebuild.
        //
        // Anchor the path against `CARGO_MANIFEST_DIR` rather than the
        // process CWD: some test runners run with a different working
        // directory (and `prune_old_versions_removes_only_stale_lsp_dirs`
        // also mutates CWD), so a relative read is fragile.
        let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
        let on_disk = fs::read_to_string(manifest_dir.join("shared/lex-deps.json"))
            .expect("shared/lex-deps.json should exist next to Cargo.toml (CARGO_MANIFEST_DIR)");
        let embedded: Value = serde_json::from_str(LEX_DEPS_JSON).unwrap();
        let from_disk: Value = serde_json::from_str(&on_disk).unwrap();
        assert_eq!(
            embedded, from_disk,
            "embedded LEX_DEPS_JSON drifted from shared/lex-deps.json",
        );
    }

    #[test]
    fn prune_old_versions_removes_only_stale_lsp_dirs() {
        // Scratch dir so the test cannot disturb the real cwd.
        let scratch =
            std::env::temp_dir().join(format!("zed-lex-prune-test-{}", std::process::id()));
        let _ = fs::remove_dir_all(&scratch);
        fs::create_dir_all(&scratch).unwrap();

        let keep = "lexd-lsp-v0.8.8";
        let stale = "lexd-lsp-v0.8.7";
        let unrelated = "some-other-cache";
        for d in [keep, stale, unrelated] {
            fs::create_dir_all(scratch.join(d)).unwrap();
        }

        // prune_old_versions operates on ".", so we chdir for the call.
        // The RAII guard (a) serialises against any other CWD-touching test
        // via CWD_MUTEX and (b) restores the previous CWD on drop — even
        // if an assertion below panics.
        {
            let _cwd = CwdGuard::chdir(&scratch);
            prune_old_versions(keep);
        }

        assert!(scratch.join(keep).exists(), "kept dir should remain");
        assert!(
            !scratch.join(stale).exists(),
            "stale lexd-lsp dir should be pruned",
        );
        assert!(
            scratch.join(unrelated).exists(),
            "unrelated dirs must not be touched",
        );

        let _ = fs::remove_dir_all(&scratch);
    }
}
