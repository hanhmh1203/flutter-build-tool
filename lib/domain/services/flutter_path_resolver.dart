import 'dart:io';

class FlutterPathResolver {
  const FlutterPathResolver();

  static const _relativeToHome = [
    'fvm/default/bin/flutter',
    '.fvm/default/bin/flutter',
    'flutter/bin/flutter',
    'development/flutter/bin/flutter',
    'src/flutter/bin/flutter',
  ];

  /// Finds the flutter binary using multiple strategies.
  ///
  /// Pass [projectDir] to also check a project-local FVM installation first.
  /// Returns the full path, or 'flutter' as a last-resort fallback.
  Future<String> resolve({String? projectDir}) async {
    // 1. Project-local FVM
    if (projectDir != null) {
      final fvmLocal = '$projectDir/.fvm/flutter_sdk/bin/flutter';
      if (File(fvmLocal).existsSync()) return fvmLocal;
    }

    // 2. `which flutter` via zsh interactive+login — covers .zshrc and .zprofile
    final zshFull = await _which('/bin/zsh', ['-l', '-i', '-c', 'which flutter']);
    if (zshFull != null) return zshFull;

    // 3. `which flutter` via zsh login only — covers .zprofile / .zshenv
    final zshLogin = await _which('/bin/zsh', ['-l', '-c', 'which flutter']);
    if (zshLogin != null) return zshLogin;

    // 4. `which flutter` via bash login — covers .bash_profile / .bashrc
    final bash = await _which('/bin/bash', ['-l', '-c', 'which flutter']);
    if (bash != null) return bash;

    // 5. Common installation directories relative to $HOME
    final home = Platform.environment['HOME'];
    if (home != null) {
      for (final rel in _relativeToHome) {
        final full = '$home/$rel';
        if (File(full).existsSync()) return full;
      }
    }

    return 'flutter';
  }

  Future<String?> _which(String shell, List<String> args) async {
    try {
      final result = await Process.run(shell, args)
          .timeout(const Duration(seconds: 5));
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty && File(path).existsSync()) return path;
      }
    } catch (_) {}
    return null;
  }
}
