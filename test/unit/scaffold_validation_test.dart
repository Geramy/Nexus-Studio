// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_projects_client/features/projects/orchestration/scaffold_validation.dart';

void main() {
  group('scaffoldHasEntryPoint', () {
    test('recognises .tsx / .jsx React entry points (the templater bug)', () {
      expect(scaffoldHasEntryPoint({'main.tsx'}), isTrue);
      expect(scaffoldHasEntryPoint({'index.tsx'}), isTrue);
      expect(scaffoldHasEntryPoint({'src', 'main.jsx'}), isTrue);
      // Nested, real-world layout.
      expect(
        scaffoldHasEntryPoint({'src/main.tsx', 'src/app/page.tsx'}),
        isTrue,
      );
    });

    test('recognises Next.js App/Pages Router entries', () {
      expect(scaffoldHasEntryPoint({'src/app/page.tsx'}), isTrue);
      expect(scaffoldHasEntryPoint({'src/app/page.jsx'}), isTrue);
      expect(scaffoldHasEntryPoint({'pages/_app.tsx'}), isTrue);
    });

    test('still recognises plain .ts / .js entry points', () {
      expect(scaffoldHasEntryPoint({'main.ts'}), isTrue);
      expect(scaffoldHasEntryPoint({'index.js'}), isTrue);
      expect(scaffoldHasEntryPoint({'src/index.mjs'}), isTrue);
    });

    test('recognises non-JS entry points', () {
      expect(scaffoldHasEntryPoint({'lib/main.dart'}), isTrue);
      expect(scaffoldHasEntryPoint({'main.py'}), isTrue);
      expect(scaffoldHasEntryPoint({'src/main.rs'}), isTrue);
      expect(scaffoldHasEntryPoint({'Program.cs'.toLowerCase()}), isTrue);
    });

    test('returns false when there is no entry point', () {
      expect(scaffoldHasEntryPoint({'package.json', 'tsconfig.json'}), isFalse);
      // A .tsx file that is NOT an entry base name.
      expect(
        scaffoldHasEntryPoint({'src/components/Hero.tsx'}),
        isFalse,
      );
      // .ts file whose base name is not an entry (e.g. a module).
      expect(scaffoldHasEntryPoint({'src/lib/types.ts'}), isFalse);
    });

    test('the exact project-9 file set now reports an entry point', () {
      // Mirrors the workspace that the templater built (a Vite/Next React app)
      // and previously burned its turn cap on.
      final paths = {
        '.gitignore',
        'work_template.md',
        'package.json',
        'tsconfig.json',
        'next.config.js',
        'main.tsx',
        'index.tsx',
        'src/main.tsx',
        'src/app/page.tsx',
        'src/app/layout.tsx',
      };
      expect(scaffoldHasEntryPoint(paths), isTrue);
    });
  });

  group('scaffoldHasManifest', () {
    test('recognises the manifests we generate', () {
      expect(scaffoldHasManifest({'package.json'}), isTrue);
      expect(scaffoldHasManifest({'pubspec.yaml'}), isTrue);
      expect(scaffoldHasManifest({'pyproject.toml'}), isTrue);
      expect(scaffoldHasManifest({'go.mod'}), isTrue);
    });

    test('returns false without a manifest', () {
      expect(scaffoldHasManifest({'main.tsx', 'tsconfig.json'}), isFalse);
    });
  });
}
