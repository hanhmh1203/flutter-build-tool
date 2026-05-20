import 'dart:io';

class FinderReveal {
  const FinderReveal();

  /// Opens macOS Finder, selecting (revealing) the file. Best-effort.
  Future<void> reveal(String path) async {
    try {
      await Process.run('open', ['-R', path]);
    } catch (_) {/* non-fatal */}
  }

  /// Opens the folder in macOS Finder.
  Future<void> openFolder(String path) async {
    try {
      await Process.run('open', [path]);
    } catch (_) {}
  }
}
