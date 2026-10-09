import 'dart:io';

/// OS/arch naming used by Mojang version files and runtime manifests.
class PlatformInfo {
  static String get osName {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'osx';
    return 'linux';
  }

  static bool get isArm64 {
    final v = Platform.version.toLowerCase();
    return v.contains('arm64') || v.contains('aarch64');
  }

  static bool get is32Bit {
    final v = Platform.version.toLowerCase();
    return v.contains('_ia32') || v.contains('_x86"') || v.contains('_arm"');
  }

  static String get archBits => is32Bit ? '32' : '64';

  /// Key in Mojang's java-runtime `all.json`.
  static String get runtimePlatform {
    if (Platform.isWindows) {
      if (isArm64) return 'windows-arm64';
      return is32Bit ? 'windows-x86' : 'windows-x64';
    }
    if (Platform.isMacOS) return isArm64 ? 'mac-os-arm64' : 'mac-os';
    return is32Bit ? 'linux-i386' : 'linux';
  }

  static String get classpathSeparator => Platform.isWindows ? ';' : ':';

  static String get nativeLibExtension {
    if (Platform.isWindows) return '.dll';
    if (Platform.isMacOS) return '.dylib';
    return '.so';
  }
}
