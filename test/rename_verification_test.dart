import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Verifies the `JagadAI` → `jagad_ai` package rename invariants.
///
/// These tests protect against silent regressions of the rename:
/// 1. The Dart package name must be a valid lowercase-with-underscores name.
/// 2. No stale `package:JagadAI/...` imports may exist anywhere.
/// 3. Every `package:jagad_ai/...` import must resolve to a real file.
/// 4. Display branding ("JagadAI") must be preserved (title, Android label).
/// 5. Persistence keys must NOT be renamed (would wipe users' saved profiles).
/// 6. Web PWA metadata must not carry the stale "bow_ai" name.
void main() {
  final projectRoot = Directory.current;

  // ---------------------------------------------------------------
  // TEST 1: pubspec package name is valid & lowercase-with-underscores
  // ---------------------------------------------------------------
  test('pubspec.yaml declares a valid lowercase package name "jagad_ai"',
      () {
    final pubspec = File('${projectRoot.path}/pubspec.yaml');
    expect(pubspec.existsSync(), isTrue,
        reason: 'pubspec.yaml must exist at project root');

    final nameLine = pubspec
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('name:'), orElse: () => '');
    expect(nameLine, isNotEmpty, reason: 'pubspec.yaml must have a name: line');

    final name = nameLine.split(':').last.trim();
    // Dart package names: lowercase letters, digits, and underscores only.
    final validName = RegExp(r'^[a-z_][a-z0-9_]*$');
    expect(validName.hasMatch(name), isTrue,
        reason: 'Package name "$name" is not a valid Dart package name');
    expect(name, 'jagad_ai');
  });

  // ---------------------------------------------------------------
  // TEST 2: no stale uppercase `package:JagadAI` imports exist
  // ---------------------------------------------------------------
  test('no file references the old package:JagadAI import path', () {
    final staleMatches = <String>[];
    // Scan only lib/ (the package source). Scanning the project root would
    // match the literal strings inside this very test file (false positive).
    _walkDartFiles(Directory('${projectRoot.path}/lib'), (path) {
      for (final line in File(path).readAsLinesSync()) {
        if (line.contains('package:JagadAI') ||
            line.contains('package:JAGAD_AI')) {
          staleMatches.add('$path: $line');
        }
      }
    });
    expect(staleMatches, isEmpty,
        reason: 'Stale old-package imports found:\n${staleMatches.join('\n')}');
  });

  // ---------------------------------------------------------------
  // TEST 3: every `package:jagad_ai/...` import resolves to a real file
  // ---------------------------------------------------------------
  test('all package:jagad_ai imports resolve to existing files', () {
    final unresolved = <String>[];
    final importRe = RegExp(r"package:jagad_ai/([^']+)");

    _walkDartFiles(Directory('${projectRoot.path}/lib'), (path) {
      for (final line in File(path).readAsLinesSync()) {
        final match = importRe.firstMatch(line);
        if (match != null) {
          final target = File('${projectRoot.path}/lib/${match.group(1)}');
          if (!target.existsSync()) {
            unresolved.add('$path -> ${match.group(1)}');
          }
        }
      }
    });
    expect(unresolved, isEmpty,
        reason: 'Imports resolving to missing files:\n'
            '${unresolved.join('\n')}');
  });

  // ---------------------------------------------------------------
  // TEST 4: display branding "JagadAI" preserved
  // ---------------------------------------------------------------
  test('display branding "JagadAI" is preserved in app & Android label', () {
    final mainDart = File('${projectRoot.path}/lib/main.dart').readAsStringSync();
    expect(mainDart, contains("title: 'JagadAI'"),
        reason: 'MaterialApp title must keep the "JagadAI" brand');

    final manifest =
        File('${projectRoot.path}/android/app/src/main/AndroidManifest.xml')
            .readAsStringSync();
    expect(manifest, contains('android:label="JagadAI"'),
        reason: 'Android launcher label must keep the "JagadAI" brand');
  });

  // ---------------------------------------------------------------
  // TEST 5: persistence keys must NOT be renamed (data migration safety)
  // ---------------------------------------------------------------
  test('SharedPreferences storage keys are unchanged (data safety)', () {
    final service =
        File('${projectRoot.path}/lib/services/api_profile_service.dart')
            .readAsStringSync();
    expect(service, contains("'JagadAI_api_profiles'"),
        reason: 'Renaming this key would orphan all saved API profiles');
    expect(service, contains("'JagadAI_active_profile_id'"),
        reason: 'Renaming this key would orphan the active profile selection');
  });

  // ---------------------------------------------------------------
  // TEST 6: web PWA metadata no longer uses stale "bow_ai"
  // ---------------------------------------------------------------
  test('web PWA metadata uses the new brand, not "bow_ai"', () {
    final manifestFile =
        File('${projectRoot.path}/web/manifest.json');
    final indexFile = File('${projectRoot.path}/web/index.html');
    // web/ is gitignored and not committed, so it may be absent on a
    // fresh clone. Only assert when the files are present locally.
    if (!manifestFile.existsSync() || !indexFile.existsSync()) {
      markTestSkipped('web/ directory not present (gitignored, local-only)');
      return;
    }
    final manifest = manifestFile.readAsStringSync();
    expect(manifest, isNot(contains('bow_ai')));

    final indexHtml = indexFile.readAsStringSync();
    expect(indexHtml, isNot(contains('bow_ai')));
    expect(indexHtml, contains('<title>JagadAI</title>'));
  });
}

/// Recursively walks [dir] and calls [onFile] for every `*.dart` file,
/// skipping hidden directories and the gitignored `build/` output.
void _walkDartFiles(Directory dir, void Function(String path) onFile) {
  for (final entity in dir.listSync(followLinks: false)) {
    final path = entity.path;
    if (entity is Directory) {
      final name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : '';
      if (name.startsWith('.') || name == 'build') continue;
      _walkDartFiles(entity, onFile);
    } else if (entity is File && path.endsWith('.dart')) {
      onFile(path);
    }
  }
}
