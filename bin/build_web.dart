// Builds the dicom_rs Rust backend as WebAssembly for a Flutter web app.
//
// Run from your app's root (the folder with pubspec.yaml):
//
//   dart run dicom_rs:build_web
//
// The module is written to web/pkg, where dicom_rs loads it from. It is built
// without threads, so the page needs no special server headers and works on
// any static host, GitHub Pages included. No index.html changes are needed.
//
// Requirements: Rust (https://rustup.rs) and wasm-pack
// (cargo install wasm-pack). The wasm32-unknown-unknown target is added
// automatically when rustup is available.
import 'dart:io';
import 'dart:isolate';

const _usage = '''
Builds the dicom_rs WebAssembly module for Flutter web.

Usage: dart run dicom_rs:build_web [options]

Options:
  --output <dir>   Where to write the module (default: web/pkg)
  --debug          Build without optimizations (faster to build, slower to run)
  -h, --help       Show this help
''';

Future<void> main(List<String> args) async {
  var output = 'web/pkg';
  var release = true;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '-h' || '--help':
        stdout.write(_usage);
        return;
      case '--debug':
        release = false;
      case '--output' || '-o':
        if (i + 1 >= args.length) _fail('--output needs a directory.');
        output = args[++i];
      default:
        _fail('Unknown option: ${args[i]}\n\n$_usage');
    }
  }

  final crateDir = await _findRustCrate();
  final outputDir = Directory(output)..createSync(recursive: true);
  // Keep build files in the app's .dart_tool, not in the pub cache.
  final targetDir = Directory('.dart_tool/dicom_rs/wasm_target')
    ..createSync(recursive: true);

  if (await _isAvailable('rustup')) {
    await _run('rustup', ['target', 'add', 'wasm32-unknown-unknown']);
  }
  if (!await _isAvailable('wasm-pack')) {
    _fail(
      'wasm-pack was not found. Install it with `cargo install wasm-pack` '
      '(Rust itself comes from https://rustup.rs), then run this again.',
    );
  }

  stdout.writeln('Building ${crateDir.path} -> ${outputDir.absolute.path}');
  await _run(
    'wasm-pack',
    [
      'build',
      crateDir.path,
      if (release) '--release' else '--dev',
      '--target',
      'no-modules',
      '--no-typescript',
      '--out-name',
      'dicom_rs',
      '--out-dir',
      outputDir.absolute.path,
    ],
    environment: {
      // Required by the getrandom crate on wasm32-unknown-unknown.
      'RUSTFLAGS': '--cfg getrandom_backend="wasm_js"',
      'CARGO_TARGET_DIR': targetDir.absolute.path,
    },
  );
  stdout.writeln('Done. dicom_rs will load the module from ${outputDir.path}.');
}

/// The `rust/` folder next to this package's `lib/`, wherever pub put it.
Future<Directory> _findRustCrate() async {
  final libUri = await Isolate.resolvePackageUri(
    Uri.parse('package:dicom_rs/dicom_rs.dart'),
  );
  if (libUri == null) {
    _fail(
      'Could not find the dicom_rs package. Run this from an app that '
      'depends on dicom_rs, after `flutter pub get`.',
    );
  }
  final packageRoot = File.fromUri(libUri).parent.parent;
  final crate = Directory.fromUri(packageRoot.uri.resolve('rust/'));
  if (!File.fromUri(crate.uri.resolve('Cargo.toml')).existsSync()) {
    _fail('The dicom_rs Rust sources are missing from ${crate.path}.');
  }
  return crate;
}

Future<bool> _isAvailable(String executable) async {
  try {
    final result = await Process.run(executable, [
      '--version',
    ], runInShell: Platform.isWindows);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    _fail(
      '`$executable ${arguments.join(' ')}` failed with exit code $exitCode.',
    );
  }
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
