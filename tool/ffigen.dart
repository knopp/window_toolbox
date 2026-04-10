import 'dart:io';

import 'package:ffigen/ffigen.dart';

String findMacSdkPath() {
  final result = Process.runSync('xcrun', [
    '--show-sdk-path',
    '--sdk',
    'macosx',
  ]);
  if (result.exitCode != 0) {
    throw StateError('Failed to get macOS SDK path: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

void main() {
  final packageRoot = Platform.script.resolve('../');

  final String entryPoint;
  final String generatedFile;
  final String assetId;
  if (Platform.isMacOS) {
    entryPoint = 'macos.h';
    generatedFile = 'macos.g.dart';
    assetId = 'macos';
  } else if (Platform.isLinux) {
    entryPoint = 'linux.h';
    generatedFile = 'linux.g.dart';
    assetId = 'linux';
  } else {
    return;
  }

  bool filter(Declaration declaration) =>
      declaration.originalName.toLowerCase().startsWith('cw_');

  FfiGenerator(
    output: Output(
      dartFile: packageRoot.resolve('lib/src/$generatedFile'),
      format: true,
      style: NativeExternalBindings(assetId: 'package:window_toolbox/$assetId'),
    ),
    headers: Headers(entryPoints: [packageRoot.resolve('src/$entryPoint')]),
    functions: Functions(include: filter),
    structs: Structs(include: filter),
    enums: Enums(include: filter),
    unions: Unions(include: filter),
    globals: Globals(include: filter),
  ).generate();
}
