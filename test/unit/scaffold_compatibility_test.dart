import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/features/projects/orchestration/scaffold_compatibility.dart';

void main() {
  group('isNextJsPackage', () {
    test('true when next is in dependencies', () {
      expect(
        isNextJsPackage(
          '{"dependencies":{"next":"^14.2.0","react":"^18.2.0"}}',
        ),
        isTrue,
      );
    });

    test('true when next is in devDependencies', () {
      expect(isNextJsPackage('{"devDependencies":{"next":"^14.2.0"}}'), isTrue);
    });

    test('false for a plain Vite React app (no next)', () {
      expect(
        isNextJsPackage(
          '{"dependencies":{"react":"^18.2.0"},"devDependencies":{"vite":"^5.0.0","@vitejs/plugin-react":"^4.2.1"}}',
        ),
        isFalse,
      );
    });

    test('false on invalid JSON', () {
      expect(isNextJsPackage('not json at all'), isFalse);
    });

    test('false on a JSON array', () {
      expect(isNextJsPackage('[1,2,3]'), isFalse);
    });
  });

  group('excludeTestFilesFromNextBuild', () {
    const nextTsconfig = '''
{
  "compilerOptions": {
    "target": "es5",
    "jsx": "preserve",
    "module": "esnext"
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
''';

    test('adds the test/config excludes to a bare next tsconfig', () {
      final out = excludeTestFilesFromNextBuild(nextTsconfig);
      expect(out, isNotNull);
      expect(out, contains('"vitest.config.ts"'));
      expect(out, contains('"test"'));
      expect(out, contains('"*.test.tsx"'));
      // preserves the existing node_modules entry.
      expect(out, contains('"node_modules"'));
    });

    test('output is valid JSON with every pattern present', () {
      final out = excludeTestFilesFromNextBuild(nextTsconfig)!;
      final decoded = jsonDecode(out) as Map<String, dynamic>;
      expect(decoded['exclude'], containsAll(kNextTestExcludePatterns));
      // compilerOptions untouched.
      expect((decoded['compilerOptions'] as Map)['jsx'], 'preserve');
    });

    test('is idempotent — null when everything is already excluded', () {
      final once = excludeTestFilesFromNextBuild(nextTsconfig)!;
      expect(excludeTestFilesFromNextBuild(once), isNull);
    });

    test('merges with an existing custom exclude without dropping it', () {
      const cfg = '{"compilerOptions":{},"exclude":[".next","node_modules"]}';
      final out = excludeTestFilesFromNextBuild(cfg)!;
      final decoded = jsonDecode(out) as Map<String, dynamic>;
      final excl = (decoded['exclude'] as List).cast<String>();
      expect(excl, contains('.next'));
      expect(excl, contains('node_modules'));
      expect(excl, contains('vitest.config.ts'));
    });

    test('returns null (no-op) on JSONC / unparseable input', () {
      const cfg = '{ /* comment */ "exclude": ["node_modules"] }';
      expect(excludeTestFilesFromNextBuild(cfg), isNull);
    });

    test('returns null on a JSON array (not an object)', () {
      expect(excludeTestFilesFromNextBuild('[1,2]'), isNull);
    });
  });
}
