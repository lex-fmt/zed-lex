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
