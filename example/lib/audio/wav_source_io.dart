import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// 굽은 WAV 를 임시 디렉터리에 한 번만 떨어뜨리고 그 경로로 재생한다.
///
/// 절차적으로 만든 소리라 앱을 지우면 함께 사라져야 하므로 시스템 임시
/// 디렉터리를 쓴다. `path_provider` 를 붙이지 않는 이유이기도 하다 —
/// 이 파일들은 보존할 가치가 없다.
Future<Source> makeSource(String name, Uint8List wav) async {
  final dir = Directory('${Directory.systemTemp.path}/provis_audio');
  if (!await dir.exists()) await dir.create(recursive: true);

  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  final file = File('${dir.path}/$safe.wav');
  // 길이가 같으면 같은 소리다. 시드가 결정론적이므로 내용까지 비교할 필요가 없다.
  if (!await file.exists() || await file.length() != wav.length) {
    await file.writeAsBytes(wav, flush: true);
  }
  return DeviceFileSource(file.path);
}
