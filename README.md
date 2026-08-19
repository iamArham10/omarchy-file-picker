# 🔍 Omarchy File Picker (`arh.file-picker`)

A high-performance, theme-aware fuzzy file search plugin and launcher for **[Omarchy](https://omarchy.org/)** and **Hyprland**.

Quickly find and open documents, notes, videos, audio, images, and code files from your configured directories using either a **native Quickshell overlay** or an **interactive terminal TUI**.

---

<p align="center">
  <img src="preview.png" alt="Omarchy File Picker Preview" width="850" />
</p>

---

## ✨ Features

- ⚡ **Lightning Fast Scanning**: Uses `fd` (with fallback to `find`) for sub-50ms directory indexing with background caching.
- 🗂️ **Configurable Directories & File Types**: Simple JSON configuration (`~/.config/omarchy/file-picker.json`) to add/remove search folders, categories, and exclusions.
- 🎨 **Native Omarchy Shell UI**: Seamlessly inherits active Omarchy themes, border radius, fonts, colors, and shadows.
- 🖼️ **Live Image Preview**: Displays image thumbnails directly inside the preview card when browsing image files.
- 🏷️ **Category Filtering**: Instant category pills for **All**, **Docs** (PDF, DOCX, CSV), **Notes** (Markdown, Org), **Videos** (MP4, MKV), **Audio** (MP3, FLAC), **Images** (PNG, JPG, WebP), and **Code** (Rust, Python, Go, JS/TS, Lua, etc.).
- ⌨️ **Dual Mode Support**:
  - **Native GUI Overlay**: Floating Quickshell layer overlay with live search and metadata preview.
  - **Terminal TUI**: Interactive `fzf` picker with rich syntax-highlighted previews (`pdftotext`, `ffprobe`, `bat`, `head`).
- 🔗 **Action Shortcuts**: Open file (`Enter`), open folder in file manager (`Alt+Enter`), or copy file path (`Shift+Enter`).

---

## 📦 Installation

Install and enable the plugin directly with the Omarchy CLI:

```bash
omarchy plugin add https://github.com/iamArham10/omarchy-file-picker.git --enable
```

---

## ⌨️ Hyprland Keybinding Configuration

Add the keybinding to your `~/.config/hypr/bindings.lua`:

### Option A: Native Omarchy GUI Overlay (`SUPER + I`)
```lua
-- File picker native GUI overlay
o.bind("SUPER + I", "Fuzzy file picker", "omarchy-shell shell toggle arh.file-picker")
```

### Option B: Floating Terminal TUI with fzf (`SUPER + I`)
```lua
-- File picker terminal fzf window
o.bind("SUPER + I", "Fuzzy file picker", "alacritty --title fzf-picker -e omarchy-file-picker --tui")
```

---

## ⚙️ Configuration

The configuration file is automatically created at:
```
~/.config/omarchy/file-picker.json
```

You can open and edit it anytime by running:
```bash
omarchy-file-picker --config
```

### Example `~/.config/omarchy/file-picker.json`

```json
{
  "directories": [
    "~/Documents",
    "~/Downloads",
    "~/Desktop",
    "~/Github",
    "~/Videos",
    "~/Music",
    "~/Pictures",
    "~/Obsidian"
  ],
  "categories": {
    "all": [],
    "documents": ["pdf", "epub", "djvu", "docx", "pptx", "xlsx", "txt", "csv", "odt", "ods", "odp", "rtf"],
    "notes": ["md", "markdown", "org", "rst", "adoc"],
    "videos": ["mp4", "mkv", "avi", "mov", "webm", "flv", "wmv", "m4v"],
    "audio": ["mp3", "flac", "ogg", "wav", "m4a", "aac", "opus"],
    "images": ["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "avif"],
    "code": ["py", "rs", "go", "js", "ts", "jsx", "tsx", "c", "cpp", "h", "hpp", "sh", "bash", "zsh", "lua", "json", "toml", "yaml", "yml"]
  },
  "excludeDirectories": [
    "node_modules",
    ".git",
    ".svn",
    ".hg",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    ".cache",
    ".tmp",
    "tmp",
    "temp",
    "dist",
    "build",
    "out",
    ".next",
    ".nuxt",
    ".svelte-kit",
    ".output",
    "vendor",
    "venv",
    ".venv",
    "env",
    ".env",
    "target",
    ".cargo",
    ".gradle",
    ".m2",
    "bin",
    "obj",
    ".idea",
    ".vscode",
    "coverage",
    ".nyc_output",
    "logs"
  ],
  "cacheTtlSeconds": 300,
  "maxResults": 2000
}
```

---

## 🚀 CLI Commands

```bash
# Toggle the GUI overlay
omarchy-file-picker

# Launch the interactive terminal TUI
omarchy-file-picker --tui

# Pre-filter by category
omarchy-file-picker --category notes
omarchy-file-picker --tui --category videos

# Re-index all directories and force refresh the cache
omarchy-file-picker --refresh

# Open the JSON configuration file in your editor
omarchy-file-picker --config
```

---

## ⌨️ Shortcuts in Picker

| Key | Action |
|---|---|
| `↑` / `↓` or `Ctrl+K` / `Ctrl+J` | Navigate file list |
| `Enter` | Open selected file in default app (`xdg-open`) |
| `Alt + Enter` | Open containing directory |
| `Shift + Enter` | Copy file path to clipboard (`wl-copy`) |
| `Tab` / `Shift + Tab` | Cycle category filter pills |
| `F5` or `Ctrl + R` | Force refresh cache |
| `Esc` | Clear search query or close picker |

---

## 🔒 Security & Scope

- **Local Execution Only**: No network requests, telemetry, or external API calls.
- **Sandboxed Caching**: File metadata cache is stored strictly in user space (`~/.cache/omarchy/file-picker/`).
- **Standard Desktop Integration**: Uses standard `xdg-open` to launch user-selected files in their chosen system apps.

---

## 🛠️ Verification & Development

To validate the plugin against the Omarchy shell manifest schema:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/arh.file-picker
```

To reload plugins after modifying QML files:

```bash
omarchy-shell shell rescanPlugins
```

---

## 📜 License

[MIT License](LICENSE) © 2026 Arham Imran
