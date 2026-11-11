// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_projects_client/infrastructure/nextify/nextify_deploy.dart';

void main() {
  group('nextifyNodeDeployScript', () {
    test('embeds the repo URL, branch, and port', () {
      final s = nextifyNodeDeployScript(
        repoUrl: 'https://github.com/Geramy/my-site.git',
        branch: 'main',
        appPort: 3000,
      );
      expect(s, startsWith('#!/bin/bash'));
      expect(s, contains("REPO='https://github.com/Geramy/my-site.git'"));
      expect(s, contains("BRANCH='main'"));
      expect(s, contains('PORT=3000'));
      // No leftover placeholders.
      expect(s, isNot(contains('__REPO__')));
      expect(s, isNot(contains('__BRANCH__')));
      expect(s, isNot(contains('__PORT__')));
    });

    test('empty branch leaves BRANCH empty (clone default branch)', () {
      final s = nextifyNodeDeployScript(
        repoUrl: 'https://github.com/Geramy/my-site.git',
      );
      expect(s, contains("BRANCH=''"));
    });

    test('single quotes in the value are escaped', () {
      final s = nextifyNodeDeployScript(repoUrl: "https://x/it's.git");
      // 'it'\''s' is the standard single-quote escape.
      expect(s, contains("REPO='https://x/it'\\''s.git'"));
    });

    test('custom port is threaded through to nginx + service', () {
      final s = nextifyNodeDeployScript(
        repoUrl: 'https://github.com/Geramy/x.git',
        appPort: 8080,
      );
      expect(s, contains('PORT=8080'));
      // nginx is written via an unquoted heredoc, so it references the $PORT
      // bash variable (expanded at first boot), not the literal number.
      expect(s, contains('proxy_pass http://127.0.0.1:\$PORT;'));
    });

    test('installs Node 20, clones, builds, and runs a systemd service', () {
      final s = nextifyNodeDeployScript(repoUrl: 'https://github.com/Geramy/x.git');
      expect(s, contains('setup_20.x'));
      expect(s, contains('git clone'));
      expect(s, contains('npm run build'));
      expect(s, contains('nexus-app.service'));
      expect(s, contains('systemctl enable nexus-app.service'));
      expect(s, contains('listen 80 default_server'));
    });

    test('local mode omits the git clone + REPO/BRANCH but keeps the build', () {
      final s = nextifyNodeDeployScript(local: true, appPort: 3000);
      // No git source at all.
      expect(s, isNot(contains('git clone')));
      expect(s, isNot(contains('REPO=')));
      expect(s, isNot(contains('BRANCH=')));
      // Still installs node, builds, runs systemd + nginx.
      expect(s, contains('setup_20.x'));
      expect(s, contains('npm run build'));
      expect(s, contains('nexus-app.service'));
      expect(s, contains('listen 80 default_server'));
      expect(s, contains('PORT=3000'));
      // The serve script bakes in the literal port: `process.env.PORT` is not
      // exported, so reading it at generation time yields `undefined` and the
      // app would run `next start -p undefined` (exit 1).
      expect(s, contains('"next start -p 3000"'));
      expect(s, isNot(contains('process.env.PORT')));
      // The nginx variables are backslash-escaped so the unquoted heredoc passes
      // them through literally; an unescaped `$http_upgrade` dies under `set -u`
      // before the reverse-proxy config is applied (=> default nginx page).
      expect(s, contains(r'proxy_set_header Upgrade \$http_upgrade;'));
      expect(s, contains(r'proxy_set_header Host \$host;'));
      // No leftover placeholders.
      expect(s, isNot(contains('__VAR_HEAD__')));
      expect(s, isNot(contains('__CLONE__')));
      expect(s, isNot(contains('__PORT__')));
    });
  });
}
