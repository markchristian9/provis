import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// 웹에는 파일 시스템이 없다. `BytesSource` 는 웹에서 구현되어 있으므로
/// 바이트를 그대로 넘긴다.
Future<Source> makeSource(String name, Uint8List wav) async =>
    BytesSource(wav, mimeType: 'audio/wav');
