import 'dart:io';

import 'package:native_toolchain_ninja/native_toolchain_ninja.dart';
import 'package:code_assets/code_assets.dart';
import 'package:logging/logging.dart';
import 'package:hooks/hooks.dart';

Future<List<String>> _pkgConfig(String flag, String packageName) async {
  final result = await Process.run('pkg-config', [flag, packageName]);
  if (result.exitCode != 0) {
    throw BuildError(message: 'pkg-config failed: ${result.stderr}');
  }
  return (result.stdout as String)
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
}

void main(List<String> args) async {
  await build(args, (input, output) async {
    final packageName = input.packageName;

    if (!input.config.buildCodeAssets) {
      return;
    }

    final debugBuild = false;

    NinjaBuilder? ninjaBuilder;

    if (input.config.code.targetOS == OS.macOS) {
      ninjaBuilder = NinjaBuilder.library(
        name: packageName,
        assetName: 'macos',
        sources: ['src/macos.m'],
        language: Language.objectiveC,
        frameworks: ['AppKit'],
        flags: [
          // ignore: dead_code
          if (debugBuild) ...[
            '-O0',
            '-g3',
          ],
          "-fobjc-arc",
        ],
      );
    } else if (input.config.code.targetOS == OS.linux) {
      ninjaBuilder = NinjaBuilder.library(
        name: packageName,
        assetName: 'linux',
        sources: ['src/linux.c'],
        buildMode: BuildMode.debug,
        optimizationLevel: OptimizationLevel.o0,
        flags: [
          // ignore: dead_code
          if (debugBuild) ...[
            '-g',
          ],
          ...(await _pkgConfig('--cflags', 'gtk+-3.0')),
        ],
        language: Language.c,
        libraries: [
          // Everything we need will be linked into the final executable.
        ],
      );
    }

    if (ninjaBuilder != null) {
      await ninjaBuilder.run(
        input: input,
        output: output,
        logger: Logger('')
          ..level = .ALL
          // ignore: avoid_print
          ..onRecord.listen((record) => print(record.message)),
      );
    }
  });
}
