# Repairs the broken Windows packaging of the `git2dart_binaries` pub package.
#
# Why this is needed:
#   git2dart_binaries (>=1.10.x) ships a Windows CMakeLists.txt whose
#   `bundled_libraries` list references DLLs it does NOT include:
#       libcrypto-1_1-x64.dll  (OpenSSL 1.1 — never shipped; and it's the wrong
#                               version anyway: the bundled libssh2.dll imports
#                               libcrypto-3-x64.dll, i.e. OpenSSL 3)
#       libgit2-1.6.2.dll      (the package actually ships plain libgit2.dll)
#   so `flutter build/run windows` dies at the INSTALL/cmake_install step with
#   MSB3073 "file INSTALL cannot find ... libcrypto-1_1-x64.dll".
#   Linux/macOS are unaffected, which is why a Linux-based author never sees it.
#
# This script, for every cached git2dart_binaries version:
#   1) drops a real libcrypto-3-x64.dll (OpenSSL 3) into the package's windows/ dir
#      (the actual runtime dependency of the bundled libssh2.dll), and
#   2) rewrites bundled_libraries to reference only DLLs that exist.
#
# Re-run this after `dart pub cache repair`, after clearing the pub cache, or on a
# fresh machine, then `flutter run -d windows`. (`flutter clean` does NOT require it.)

$ErrorActionPreference = 'Stop'

# Locate a real libcrypto-3-x64.dll (OpenSSL 3). Prefer an MSVC build to match the
# MSVC-built libssh2.dll; fall back to the one Git for Windows ships.
$cryptoCandidates = @(
  'C:\Program Files\OpenSSL-Win64\libcrypto-3-x64.dll',
  'C:\Program Files\Git\mingw64\bin\libcrypto-3-x64.dll'
)
$crypto = $cryptoCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $crypto) {
  throw "No libcrypto-3-x64.dll found. Install OpenSSL 3 (Win64) or Git for Windows, then re-run."
}
Write-Host "Using OpenSSL crypto DLL: $crypto"

# Pub cache location (honor PUB_CACHE if set).
$pubCache = if ($env:PUB_CACHE) { $env:PUB_CACHE } else { Join-Path $env:LOCALAPPDATA 'Pub\Cache' }
$hosted = Join-Path $pubCache 'hosted\pub.dev'

$pkgs = Get-ChildItem -Path $hosted -Directory -Filter 'git2dart_binaries-*' -ErrorAction SilentlyContinue
if (-not $pkgs) { throw "No git2dart_binaries found in $hosted. Run `flutter pub get` first." }

foreach ($pkg in $pkgs) {
  $win = Join-Path $pkg.FullName 'windows'
  if (-not (Test-Path $win)) { continue }
  Write-Host "Patching $($pkg.Name) ..."

  # 1) Ensure libcrypto-3-x64.dll is present next to libgit2/libssh2.
  Copy-Item $crypto -Destination (Join-Path $win 'libcrypto-3-x64.dll') -Force

  # 2) Rewrite bundled_libraries to reference DLLs that actually exist.
  $cml = Join-Path $win 'CMakeLists.txt'
  $text = Get-Content $cml -Raw
  $fixed = [regex]::Replace(
    $text,
    'set\(git2dart_binaries_bundled_libraries.*?PARENT_SCOPE\s*\)',
    @"
set(git2dart_binaries_bundled_libraries
  "`${CMAKE_CURRENT_SOURCE_DIR}/libcrypto-3-x64.dll"
  "`${CMAKE_CURRENT_SOURCE_DIR}/libgit2.dll"
  "`${CMAKE_CURRENT_SOURCE_DIR}/libssh2.dll"
  PARENT_SCOPE
)
"@.Trim(),
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )
  Set-Content -Path $cml -Value $fixed -Encoding utf8
  Write-Host "  -> done."
}

Write-Host "`nAll set. Now run:  flutter run -d windows"
