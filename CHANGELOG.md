# Changelog

## 0.1.0

- Resolve `jar:` URIs from Eglot and lsp-mode instead of opening empty buffers.
- Extract sources jar entries and decompile class files.
- Detect CFR, JD-cli, Fernflower, or fall back to javap disassembly.
- Cache extracted and decompiled files by jar identity and decompiler identity.
- Open cache buffers read-only and keep language servers out of them.
- Clamp point when a decompiled file cannot honour server line numbers.
