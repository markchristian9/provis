import 'package:provis/provis.dart';
import 'chitinis.dart';
import 'gorehide.dart';
import 'mourne.dart';
import 'vaelmorth.dart';
import 'aldric.dart';
import 'kaelen.dart';
import 'lyra.dart';
import 'seraphine.dart';
import 'vesper.dart';

/// 등장 인물 명부.
///
/// UI 는 이 목록만 알면 되고, 캐릭터를 추가하려면 여기에 한 줄만 넣으면 된다.
/// 인스턴스는 상태를 갖지 않으므로(모든 애니메이션이 시간 [t] 의 순수 함수다)
/// 앱 수명 동안 하나만 만들어 공유해도 안전하다.
final List<Artist> heroes = List<Artist>.unmodifiable([
  Aldric(),
  Kaelen(),
  Seraphine(),
  Lyra(),
  Vesper(),
]);

final List<Artist> monsters = List<Artist>.unmodifiable([
  Gorehide(),
  Vaelmorth(),
  Mourne(),
  Chitinis(),
]);

final List<Artist> everyone =
    List<Artist>.unmodifiable([...heroes, ...monsters]);
