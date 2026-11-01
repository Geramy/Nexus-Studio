import 'dart:convert';

/// Test/tooling paths that must be kept OUT of a Next.js `next build` type-check.
///
/// `next build` runs the TypeScript compiler over the tsconfig's `include` set.
/// If test files or a Vitest/Vite config that pulls in a SECOND `vite` copy
/// (e.g. a `vitest.config.ts` using `@vitejs/plugin-react`) is left in that set,
/// the build fails with an unresolvable duplicate-`vite` type conflict. That
/// failure is a *dependency/config* problem the CI code-fixer cannot repair (it
/// only edits app source), so the project never converges to green. Excluding
/// these paths from the build tsconfig is the deterministic fix.
const List<String> kNextTestExcludePatterns = <String>[
  'node_modules',
  'test',
  'tests',
  '__tests__',
  'vitest.config.ts',
  'vite.config.ts',
  'jest.config.ts',
  'cypress.config.ts',
  'playwright.config.ts',
  'vitest.setup.ts',
  'jest.setup.ts',
  '*.test.ts',
  '*.test.tsx',
  '*.spec.ts',
  '*.spec.tsx',
];

/// True when [packageJson] declares the Next.js framework (a `next` dependency in
/// any of dependencies / devDependencies / optionalDependencies). Returns false
/// on any parse failure or a non-Next package — so a plain Vite/CRA React app
/// (where a Vite React plugin in a config is legitimate) is never touched.
bool isNextJsPackage(String packageJson) {
  try {
    final decoded = jsonDecode(packageJson);
    if (decoded is! Map) return false;
    for (final key in const <String>[
      'dependencies',
      'devDependencies',
      'optionalDependencies',
    ]) {
      final deps = decoded[key];
      if (deps is Map && deps.containsKey('next')) return true;
    }
  } catch (_) {
    return false;
  }
  return false;
}

/// If [tsconfigJson] is a project's tsconfig whose `exclude` would let `next
/// build` type-check test files / a Vitest-Vite config, returns the corrected
/// tsconfig (pretty 2-space JSON) with every entry of [kNextTestExcludePatterns]
/// merged into `exclude` (preserving any existing entries and their order).
///
/// Returns null when there is nothing to fix: the input isn't a parseable JSON
/// object (JSONC / comments → don't risk corrupting it) or every pattern is
/// already present (idempotent).
String? excludeTestFilesFromNextBuild(String tsconfigJson) {
  final Map<String, dynamic> cfg;
  try {
    final decoded = jsonDecode(tsconfigJson);
    if (decoded is! Map<String, dynamic>) return null;
    cfg = decoded;
  } catch (_) {
    return null;
  }
  final raw = cfg['exclude'];
  final current = raw is List ? raw.whereType<String>().toList() : <String>[];
  final missing = <String>[
    for (final p in kNextTestExcludePatterns)
      if (!current.contains(p)) p,
  ];
  if (missing.isEmpty) return null;
  cfg['exclude'] = <String>[...current, ...missing];
  return '${const JsonEncoder.withIndent('  ').convert(cfg)}\n';
}
