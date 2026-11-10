// Copyright (c) 2026 Geramy Loveless DBA Nexus Projects.
// Author: Geramy Loveless <support@nexus-projects.ai>
// Licensed under the Sustainable Use License. See LICENSE.md.

import 'package:nexus_projects_client/infrastructure/workspace/workspace.dart';

/// A prefilled container recipe for a project: a starter [dockerfile] tuned to
/// the detected [kind], the container port the image exposes, and a sensible
/// default host port. The user edits any of these before launching, and the
/// Dockerfile is written into the project so it can be edited later too.
class DockerLaunchTemplate {
  final String kind;
  final String dockerfile;
  final int containerPort;
  final int hostPort;
  const DockerLaunchTemplate({
    required this.kind,
    required this.dockerfile,
    required this.containerPort,
    required this.hostPort,
  });
}

/// What [detectDockerProject] found: the stack [kind], the [subdir] (relative to
/// the build-context root) that actually HOLDS the project manifest — often a
/// nested folder like `client/`, which is why the build must `cd` into it rather
/// than run at the root — and, for .NET, the entry [dotnetAssembly] (the
/// `.csproj` name) used for `dotnet <name>.dll`.
class DockerProjectInfo {
  final String kind;
  final String subdir; // '' when the manifest is at the context root
  final String? dotnetAssembly;
  const DockerProjectInfo({
    required this.kind,
    this.subdir = '',
    this.dotnetAssembly,
  });
}

bool _ignoredDir(String rel) {
  final l = '/${rel.toLowerCase()}/';
  return l.contains('/build/') ||
      l.contains('/.dart_tool/') ||
      l.contains('/node_modules/') ||
      l.contains('/bin/') ||
      l.contains('/obj/') ||
      l.contains('/.git/');
}

/// Detect the project's stack AND the subdirectory that holds its manifest, so a
/// prefilled Dockerfile builds the REAL project even when it's nested (e.g. a
/// Flutter app under `client/`, or a .NET `.csproj` in a project folder).
/// Best-effort; defaults to `generic` at the root. Picks the SHALLOWEST manifest.
Future<DockerProjectInfo> detectDockerProject(Workspace ws) async {
  final List<String> paths;
  try {
    paths = (await ws.walk())
        .where((f) => !f.isDirectory)
        .map((f) => f.path.startsWith('/') ? f.path.substring(1) : f.path)
        .toList();
  } catch (_) {
    return const DockerProjectInfo(kind: 'generic');
  }

  int depthOf(String rel) => rel.contains('/')
      ? rel.substring(0, rel.lastIndexOf('/')).split('/').where((s) => s.isNotEmpty).length
      : 0;
  String dirOf(String rel) =>
      rel.contains('/') ? rel.substring(0, rel.lastIndexOf('/')) : '';

  String? bestKind;
  String? bestRel;
  var bestDepth = 1 << 30;
  String? csprojRel;
  for (final rel in paths) {
    if (_ignoredDir(rel)) continue;
    final name = rel.split('/').last.toLowerCase();
    String? kind;
    if (name == 'pubspec.yaml') {
      kind = 'pubspec'; // flutter vs dart resolved below
    } else if (name == 'package.json') {
      kind = 'node';
    } else if (name == 'requirements.txt' ||
        name == 'pyproject.toml' ||
        name == 'pipfile') {
      kind = 'python';
    } else if (name == 'go.mod') {
      kind = 'go';
    } else if (name == 'cargo.toml') {
      kind = 'rust';
    } else if (name.endsWith('.sln')) {
      kind = 'dotnet';
    } else if (name.endsWith('.csproj')) {
      kind = 'dotnet';
      csprojRel ??= rel;
    }
    if (kind == null) continue;
    final depth = depthOf(rel);
    if (depth < bestDepth) {
      bestDepth = depth;
      bestKind = kind;
      bestRel = rel;
    }
  }

  if (bestKind == null || bestRel == null) {
    return const DockerProjectInfo(kind: 'generic');
  }

  var kind = bestKind;
  String? dotnetAssembly;
  if (kind == 'dotnet') {
    // Entry dll = the .csproj basename (the .sln itself isn't a runnable dll).
    if (csprojRel != null) {
      dotnetAssembly = csprojRel
          .split('/')
          .last
          .replaceAll(RegExp(r'\.csproj$', caseSensitive: false), '');
    }
  } else if (kind == 'pubspec') {
    kind = 'dart';
    try {
      final content = await ws.readString('/$bestRel');
      if (content.contains('flutter:') || content.contains('sdk: flutter')) {
        kind = 'flutter';
      }
    } catch (_) {}
  } else if (kind == 'node') {
    // A Next.js app is served with `next start`, which only works if a prior
    // `next build` produced the `.next` production output. Detect it so the
    // Dockerfile runs that build step — otherwise the container starts, can't
    // find `.next`, and exits within a second (the "site doesn't work at all"
    // launch: a dead localhost port with nothing behind it).
    var isNext = false;
    try {
      final pkg = await ws.readString('/$bestRel');
      if (RegExp(r'"next"\s*:').hasMatch(pkg)) isNext = true;
    } catch (_) {}
    if (!isNext) {
      final dir = dirOf(bestRel);
      for (final rel in paths) {
        if (dirOf(rel) != dir) continue;
        if (RegExp(r'^next\.config\.(js|ts|mjs|cjs|json)$')
            .hasMatch(rel.split('/').last)) {
          isNext = true;
          break;
        }
      }
    }
    if (isNext) kind = 'next';
  }
  return DockerProjectInfo(
    kind: kind,
    subdir: dirOf(bestRel),
    dotnetAssembly: dotnetAssembly,
  );
}

/// Backwards-compatible stack-only detection (kind of the project).
Future<String> detectDockerStackKind(Workspace ws) async =>
    (await detectDockerProject(ws)).kind;

/// Build a prefilled [DockerLaunchTemplate] for [kind]. These are STARTER recipes
/// — correct for a typical project of that stack and meant to be edited. When the
/// project lives in a nested [subdir] the build `cd`s into it (so `dotnet
/// restore` / `flutter build` / `npm install` find the manifest); [dotnetAssembly]
/// names the .NET entry dll.
DockerLaunchTemplate dockerLaunchTemplate(
  String kind, {
  String subdir = '',
  String? dotnetAssembly,
}) {
  // Normalize the subdir into a POSIX path segment for the container.
  final sub = subdir.replaceAll(r'\', '/').replaceAll(RegExp(r'^/+|/+$'), '');
  final hasSub = sub.isNotEmpty;

  switch (kind) {
    case 'flutter':
      // A Flutter desktop/mobile binary can't run in a Linux container, but the
      // web build can — compile it and serve the static site with nginx.
      final app = hasSub ? '/app/$sub' : '/app';
      return DockerLaunchTemplate(
        kind: 'flutter',
        containerPort: 80,
        hostPort: 8080,
        dockerfile:
            '''
# --- Build the Flutter web app ---
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
# Build in the app directory (the folder holding pubspec.yaml).
WORKDIR $app
# Add the web platform if the project wasn't scaffolded for it (safe: only
# generates the missing web/ shell + config, never touches lib/ source).
RUN flutter create . --platforms web
RUN flutter pub get
RUN flutter build web --release

# --- Serve the static build with nginx ---
FROM nginx:alpine
COPY --from=build $app/build/web /usr/share/nginx/html
EXPOSE 80
''',
      );
    case 'dart':
      final app = hasSub ? '/app/$sub' : '/app';
      return DockerLaunchTemplate(
        kind: 'dart',
        containerPort: 8080,
        hostPort: 8080,
        dockerfile:
            '''
FROM dart:stable AS build
WORKDIR /app
COPY . .
WORKDIR $app
RUN dart pub get
RUN dart compile exe bin/main.dart -o bin/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build $app/bin/server /app/bin/server
EXPOSE 8080
CMD ["/app/bin/server"]
''',
      );
    case 'next':
      // Next.js: `next start` (the default `npm start`) serves a COMPILED
      // production build, so the image must run `next build` first to produce
      // `.next`. A full `npm install` is required — dev deps (typescript,
      // tailwind, postcss, ...) are needed to build. Single-stage for
      // simplicity; swap for multi-stage to slim the image if desired.
      final app = hasSub ? '/app/$sub' : '/app';
      return DockerLaunchTemplate(
        kind: 'next',
        containerPort: 3000,
        hostPort: 3000,
        dockerfile:
            '''
FROM node:20-alpine
WORKDIR /app
COPY . .
WORKDIR $app
# Install every dependency — dev deps (typescript, tailwind, ...) build the app.
RUN npm install
# Produce the production build that `next start` serves (the .next directory).
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]
''',
      );
    case 'node':
      final app = hasSub ? '/app/$sub' : '/app';
      return DockerLaunchTemplate(
        kind: 'node',
        containerPort: 3000,
        hostPort: 3000,
        dockerfile:
            '''
FROM node:20-alpine
WORKDIR /app
COPY . .
WORKDIR $app
RUN npm install --omit=dev
EXPOSE 3000
CMD ["npm", "start"]
''',
      );
    case 'python':
      final app = hasSub ? '/app/$sub' : '/app';
      return DockerLaunchTemplate(
        kind: 'python',
        containerPort: 8000,
        hostPort: 8000,
        dockerfile:
            '''
FROM python:3.12-slim
WORKDIR /app
COPY . .
WORKDIR $app
RUN pip install --no-cache-dir -r requirements.txt
EXPOSE 8000
# Edit this to your app's entrypoint (module:app for ASGI/WSGI, or a script).
CMD ["python", "main.py"]
''',
      );
    case 'go':
      final app = hasSub ? '/app/$sub' : '/app';
      return DockerLaunchTemplate(
        kind: 'go',
        containerPort: 8080,
        hostPort: 8080,
        dockerfile:
            '''
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY . .
WORKDIR $app
RUN go mod download
RUN go build -o /app/server ./...

FROM alpine:latest
COPY --from=build /app/server /server
EXPOSE 8080
CMD ["/server"]
''',
      );
    case 'rust':
      final app = hasSub ? '/app/$sub' : '/app';
      return DockerLaunchTemplate(
        kind: 'rust',
        containerPort: 8080,
        hostPort: 8080,
        dockerfile:
            '''
FROM rust:latest AS build
WORKDIR /app
COPY . .
WORKDIR $app
RUN cargo build --release

FROM debian:bookworm-slim
COPY --from=build $app/target/release/app /usr/local/bin/app
EXPOSE 8080
CMD ["app"]
''',
      );
    case 'dotnet':
      // Build in the folder holding the .csproj/.sln (often nested), then run the
      // detected entry assembly.
      final src = hasSub ? '/src/$sub' : '/src';
      final dll = (dotnetAssembly != null && dotnetAssembly.trim().isNotEmpty)
          ? '${dotnetAssembly.trim()}.dll'
          : 'App.dll';
      return DockerLaunchTemplate(
        kind: 'dotnet',
        containerPort: 8080,
        hostPort: 8080,
        dockerfile:
            '''
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
# Restore + publish from the project directory (holds the .csproj / .sln).
WORKDIR $src
RUN dotnet restore
RUN dotnet publish -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app ./
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
# Detected entry assembly (edit if your published dll differs).
ENTRYPOINT ["dotnet", "$dll"]
''',
      );
    default:
      return const DockerLaunchTemplate(
        kind: 'generic',
        containerPort: 8080,
        hostPort: 8080,
        dockerfile: '''
# Starter Dockerfile — edit for your project's stack.
FROM alpine:latest
WORKDIR /app
COPY . .
EXPOSE 8080
CMD ["sh", "-c", "echo 'Edit this Dockerfile to build and run your project' && sleep infinity"]
''',
      );
  }
}
