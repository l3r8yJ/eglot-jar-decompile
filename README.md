# eglot-jar-decompile

Jump to library sources from Eglot and lsp-mode without landing in an empty buffer.

When a language server answers go-to-definition for a dependency, it can return a URI such as:

```
jar:///home/me/.gradle/caches/.../spring-web-7.0.9-sources.jar!/org/springframework/http/ResponseEntity.java
jar:///home/me/.gradle/caches/.../contracts-3.0.34.jar!/com/example/Contract.class
```

Eglot and lsp-mode hand that string to `find-file`, which cannot visit a jar entry and opens an empty buffer. `eglot-jar-decompile` turns the URI into a real file:

- sources jar entry: extracted unchanged;
- class file: decompiled to `.java` with an external decompiler.

Both clients are supported from the same mode.

## Installation

Until the package is on MELPA:

```elisp
(package-vc-install "https://github.com/l3r8yJ/eglot-jar-decompile")
```

Enable it once:

```elisp
(eglot-jar-decompile-mode 1)
```

Nothing is advised while the mode is off.

## Decompiler

One decompiler must be installed. Detection order:

1. `eglot-jar-decompile-decompiler-program` (executable, or a Fernflower jar);
2. `cfr` on `PATH`;
3. `jd-cli` on `PATH`;
4. Fernflower from an IntelliJ Toolbox or system install;
5. `javap -p -c` disassembly, when `eglot-jar-decompile-javap-fallback` is non-nil.

Force a choice with `eglot-jar-decompile-decompiler`, one of `auto`, `cfr`, `jd-cli`, `fernflower`, `javap`. With no decompiler available, the jump fails with an actionable error instead of a blank buffer.

Extraction uses the JDK `jar` tool, so no `unzip` dependency is needed.

## Usage

- `M-.` on a dependency symbol in an Eglot or lsp-mode buffer opens the source file.
- `xref-find-references` works the same way for jar entries.
- Extracted and decompiled files open read-only.

Cache lives in `$XDG_CACHE_HOME/eglot-jar-decompile/`, falling back to `~/.cache/eglot-jar-decompile/`. Delete the directory to force re-extraction. Entries are keyed by jar path, entry, jar size and mtime, operation, and decompiler identity, so changing decompilers does not serve stale output.

## Customization

| Variable | Default | Purpose |
|---|---|---|
| `eglot-jar-decompile-cache-directory` | XDG cache path | Where extracted and decompiled files live |
| `eglot-jar-decompile-decompiler` | `auto` | Decompiler selection |
| `eglot-jar-decompile-decompiler-program` | `nil` | Explicit executable or Fernflower jar |
| `eglot-jar-decompile-javap-fallback` | `t` | Allow disassembly when no decompiler works |

## Limitations

- Materialization is eager. `xref-find-references` across many uncached library classes starts the decompiler once per class; repeats hit the cache.
- Decompiled Kotlin classes are shown as Java-shaped output from a Java decompiler. Only sources jars give the original source.
- Nested fat-jar URIs (`app.jar!/BOOT-INF/lib/dep.jar!/Foo.class`) are rejected with an error.
- Local files only; TRAMP is not supported.
- CI covers Linux. macOS and Windows parsing is implemented, but untested there.

## Development

```sh
just compile
just test
just lint
```

Tests build fixture jars with the JDK `jar` tool at runtime; the decompiler tests use `javac` and `javap`.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
