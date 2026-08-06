import 'package:provis/provis.dart';
import 'chitinis.dart';
import 'gorehide.dart';
import 'mourne.dart';
import 'vaelmorth.dart';
import 'aldric.dart';
import 'kaelen.dart';
import 'lyra.dart';
import 'recruits.dart';
import 'seraphine.dart';
import 'vesper.dart';

// 명부의 단일 창구. 소비자가 recruits 를 쓰려고 별도 import 를 하지
// 않도록 여기서 함께 내보낸다.
export 'recruits.dart' show recruits;

/// 등장 인물 명부.
///
/// UI 는 이 목록만 알면 되고, 캐릭터를 추가하려면 여기에 한 줄만 넣으면 된다.
/// 인스턴스는 상태를 갖지 않으므로(모든 애니메이션이 시간 [t] 의 순수 함수다)
/// 앱 수명 동안 하나만 만들어 공유해도 안전하다.
/// 손으로 그린 간판 캐릭터 다섯.
///
/// 파츠를 하나하나 배치하므로 개성의 상한이 없다 — 대신 한 명에 700~1300 줄이
/// 든다. 각자 [Artist.build] 를 오버라이드해 게임 액터가 초상과 같은 인물로
/// 보이게 한다.
final List<Artist> signatureHeroes = List<Artist>.unmodifiable([
  Aldric(),
  Kaelen(),
  Seraphine(),
  Lyra(),
  Vesper(),
]);

/// 명부 전체. 간판 다섯 + 선언으로 만든 스무 명.
final List<Artist> heroes =
    List<Artist>.unmodifiable([...signatureHeroes, ...recruits]);

final List<Artist> monsters = List<Artist>.unmodifiable([
  Gorehide(),
  Vaelmorth(),
  Mourne(),
  Chitinis(),
]);

final List<Artist> everyone =
    List<Artist>.unmodifiable([...heroes, ...monsters]);
