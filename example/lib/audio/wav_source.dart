/// WAV 바이트를 재생 가능한 [Source] 로 바꾸는 통로.
///
/// ## 왜 플랫폼마다 다른가
///
/// `audioplayers` 의 `BytesSource` 는 **macOS·iOS·Linux 에서 구현되어 있지
/// 않다.** 그래서 바이트를 그대로 넘기면 데스크톱에서만 조용히 아무 소리도
/// 나지 않는다. 네이티브에서는 임시 파일로 한 번 떨어뜨린 뒤 파일 경로로
/// 재생하고, 웹에서는 파일 시스템이 없으므로 바이트를 그대로 넘긴다.
library;

export 'wav_source_io.dart'
    if (dart.library.js_interop) 'wav_source_web.dart';
