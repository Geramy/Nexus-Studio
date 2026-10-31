/// Pure, dependency-free heuristics used by the orchestrator's scaffold
/// validation (`_inspectScaffold` in `project_orchestrator.dart`).
///
/// Kept as top-level functions on a small file (no workspace, no DB) so the
/// filename matching is unit-testable in isolation. All inputs are already
/// lower-cased project-relative paths.
library;

/// True when the file set looks like it declares a project manifest for any
/// stack we generate (Dart, Node, Python, Rust, Go, Java, Swift, Ruby, ...).
bool scaffoldHasManifest(Iterable<String> lowerPaths) {
  const manifests = {
    'pubspec.yaml',
    'package.json',
    'pyproject.toml',
    'requirements.txt',
    'cargo.toml',
    'go.mod',
    'cmakelists.txt',
    'pom.xml',
    'build.gradle',
    'build.gradle.kts',
    'package.swift',
    'gemfile',
    'composer.json',
  };
  for (final p in lowerPaths) {
    final name = p.split('/').last;
    if (manifests.contains(name) || name.endsWith('.csproj')) return true;
  }
  return false;
}

/// True when the file set contains a main entry point.
///
/// Non-JS stacks are matched by exact filename. JS/TS is matched by **base
/// name + extension** so `.tsx`/`.jsx` and Next.js App/Pages Router entries
/// (`page.tsx`, `_app.tsx`) are recognised. This matters: a valid React/Next.js
/// scaffold only ever produces `main.tsx`/`index.tsx`/`page.tsx`, and a
/// hard-coded list of `main.ts`/`index.js` made them look "entry-point
/// missing" — so the templater burned its whole turn cap on a perfectly good
/// scaffold and reported failure.
bool scaffoldHasEntryPoint(Iterable<String> lowerPaths) {
  const explicit = {
    'main.dart',
    'main.py',
    'main.go',
    'main.rs',
    'main.c',
    'main.cpp',
    'main.java',
    'app.py',
    'program.cs',
  };
  const jsBase = {'main', 'index', 'page', '_app'};
  const jsExt = {'.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs'};
  for (final p in lowerPaths) {
    final name = p.split('/').last;
    if (explicit.contains(name)) return true;
    final dot = name.lastIndexOf('.');
    if (dot > 0) {
      final base = name.substring(0, dot);
      final ext = name.substring(dot);
      if (jsBase.contains(base) && jsExt.contains(ext)) return true;
    }
  }
  return false;
}
