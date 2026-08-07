import 'package:provis/provis.dart';

import 'lang.dart';

/// 캐릭터의 칭호와 한 줄 소개를 두 언어로 담은 표.
///
/// ## 왜 캐릭터 파일이 아니라 여기인가
///
/// [Artist] 는 라이브러리 API 다. 거기에 `titleKo` 를 더하는 순간 provis 를
/// 쓰는 모든 앱이 한국어를 알아야 한다. 캐릭터 파일은 **그 인물이 어떻게
/// 생겼는가**만 들고 있고, 어떤 말로 불리는가는 앱이 정한다.
///
/// 표에 없는 캐릭터는 [Artist.title] · [Artist.blurb] 를 그대로 쓴다. 새
/// 캐릭터를 넣고 번역을 잊어도 화면은 멀쩡히 돈다.
class LocalizedIdentity {
  const LocalizedIdentity({
    required this.titleKo,
    required this.titleEn,
    required this.blurbKo,
    required this.blurbEn,
  });

  final String titleKo;
  final String titleEn;
  final String blurbKo;
  final String blurbEn;

  String title(Lang lang) => lang == Lang.ko ? titleKo : titleEn;

  String blurb(Lang lang) => lang == Lang.ko ? blurbKo : blurbEn;
}

extension LocalizedArtist on Artist {
  /// 지금 언어로 읽은 칭호.
  String titleIn(Lang lang) => characterText[id]?.title(lang) ?? title;

  /// 지금 언어로 읽은 한 줄 소개.
  String blurbIn(Lang lang) => characterText[id]?.blurb(lang) ?? blurb;
}

/// [Artist.id] → 두 언어 정체성.
const Map<String, LocalizedIdentity> characterText = {
  // ── 간판 다섯 ─────────────────────────────────────────────────────────
  'aldric': LocalizedIdentity(
    titleKo: '제7 경야의 여명지기',
    titleEn: 'Dawnward of the Seventh Vigil',
    blurbKo: '맹세로 벼려진 판금과 꺼지지 않는 새벽빛의 성기사.',
    blurbEn: 'A paladin of oath-forged plate and dawnlight that never gutters.',
  ),
  'kaelen': LocalizedIdentity(
    titleKo: '잿빛 맹세자',
    titleEn: 'Oathsworn of Ash',
    blurbKo: '그림자를 걸치고 숨소리마저 지운 이중 단검의 처형자.',
    blurbEn: 'A twin-dagger executioner cloaked in shadow, breath and all.',
  ),
  'seraphine': LocalizedIdentity(
    titleKo: '경계의 대마법사',
    titleEn: 'Archmage of the Verge',
    blurbKo: '세계의 가장자리를 읽어 내는 창궁빛 대마법사.',
    blurbEn: 'An azure archmage who reads the edge of the world.',
  ),
  'lyra': LocalizedIdentity(
    titleKo: '가시덤불 야생의 파수꾼',
    titleEn: 'Warden of the Bramblewilds',
    blurbKo: '숨결 하나로 시위를 놓는 야생의 파수꾼.',
    blurbEn: 'A wild warden who looses the string on a single breath.',
  ),
  'vesper': LocalizedIdentity(
    titleKo: '케스트럴호의 공허 항행사',
    titleEn: 'Voidwalker of the Kestrel',
    blurbKo: '진공의 침묵을 걸어 미답의 궤도를 재는 EVA 항행사.',
    blurbEn:
        'An EVA navigator who walks vacuum silence and charts untried orbits.',
  ),

  // ── 몬스터 넷 ─────────────────────────────────────────────────────────
  'gorehide': LocalizedIdentity(
    titleKo: '살점을 찢는 거구',
    titleEn: 'The Rendering Brute',
    blurbKo: '사슬에 감긴 팔로 성문을 부수는 고산의 식인귀.',
    blurbEn: 'A highland ogre that breaks gates with chain-wrapped arms.',
  ),
  'vaelmorth': LocalizedIdentity(
    titleKo: '잿불 금고의 비룡',
    titleEn: 'Wyrm of the Cinder Vault',
    blurbKo: '갈라진 비늘 아래로 용암이 흐르는 잿불의 비룡.',
    blurbEn: 'An ember wyrm with lava running beneath split scales.',
  ),
  'mourne': LocalizedIdentity(
    titleKo: '공허의 성가대',
    titleEn: 'The Hollow Choir',
    blurbKo: '천 개의 목소리로 애도하는 형체 없는 장례의 주인.',
    blurbEn: 'A shapeless lord of funerals, mourning in a thousand voices.',
  ),
  'chitinis': LocalizedIdentity(
    titleKo: '산란 심연의 공포',
    titleEn: 'Horror of the Spawning Deep',
    blurbKo: '여덟 개의 눈으로 어둠을 읽는 산란굴의 갑각 포식자.',
    blurbEn:
        'A chitin predator of the spawning warren, reading the dark with '
        'eight eyes.',
  ),

  // ── 전사 ──────────────────────────────────────────────────────────────
  'garran': LocalizedIdentity(
    titleKo: '고갯길의 방패잡이',
    titleEn: 'Shieldbearer of the Pass',
    blurbKo: '고갯길을 혼자 막아선 방패병.',
    blurbEn: 'Held the pass alone, shield first.',
  ),
  'ilsa': LocalizedIdentity(
    titleKo: '강철 전열의 파쇄자',
    titleEn: 'Breaker of the Iron Line',
    blurbKo: '대검 한 자루로 전열을 무너뜨린다.',
    blurbEn: 'Breaks a battle line with a single greatsword.',
  ),
  'orvath': LocalizedIdentity(
    titleKo: '여명성의 맹세지기',
    titleEn: 'Oathkeeper of Dawnhold',
    blurbKo: '맹세를 지키기 위해 마지막까지 선다.',
    blurbEn: 'Stands to the last so the oath holds.',
  ),
  'brynn': LocalizedIdentity(
    titleKo: '붉은문의 파수관',
    titleEn: 'Warden of the Redgate',
    blurbKo: '붉은 문을 지키는 창병.',
    blurbEn: 'The spear that keeps the red gate shut.',
  ),

  // ── 마법사 ────────────────────────────────────────────────────────────
  'calder': LocalizedIdentity(
    titleKo: '심층 목록의 독해자',
    titleEn: 'Reader of the Deep Index',
    blurbKo: '읽어서는 안 될 목록을 외운 학자.',
    blurbEn: 'A scholar who memorized the index no one should read.',
  ),
  'maevis': LocalizedIdentity(
    titleKo: '차가운 등불의 직조사',
    titleEn: 'Weaver of Cold Lanterns',
    blurbKo: '차가운 등불을 엮어 길을 밝힌다.',
    blurbEn: 'Weaves cold lanterns to light the road.',
  ),
  'thessaly': LocalizedIdentity(
    titleKo: '불씨 소환사',
    titleEn: 'Ember Conjurer',
    blurbKo: '불씨를 손끝에 담아 두는 술사.',
    blurbEn: 'A conjurer who keeps embers at the fingertips.',
  ),
  'vaskin': LocalizedIdentity(
    titleKo: '공허의 영창자',
    titleEn: 'Hollow Chanter',
    blurbKo: '비어 있는 곳에서 노래를 듣는다.',
    blurbEn: 'Hears singing where nothing remains.',
  ),

  // ── 궁수 ──────────────────────────────────────────────────────────────
  'rhodan': LocalizedIdentity(
    titleKo: '늪지의 장사수',
    titleEn: 'Longshot of the Fen',
    blurbKo: '늪 건너편까지 화살을 보낸다.',
    blurbEn: 'Sends arrows clear across the fen.',
  ),
  'teodor': LocalizedIdentity(
    titleKo: '솔초소의 화살통',
    titleEn: 'Quiver of the Pinewatch',
    blurbKo: '소나무 초소에서 자란 사냥꾼.',
    blurbEn: 'A hunter raised at the pine watchpost.',
  ),

  // ── 군인 ──────────────────────────────────────────────────────────────
  'holt': LocalizedIdentity(
    titleKo: '제9 부대 병장',
    titleEn: 'Sergeant of the Ninth',
    blurbKo: '아홉 번째 부대를 끝까지 붙들었다.',
    blurbEn: 'Held the Ninth together to the very end.',
  ),
  'serel': LocalizedIdentity(
    titleKo: '성문 경비대장',
    titleEn: 'Marshal of the Gate Watch',
    blurbKo: '성문 경비를 지휘한다.',
    blurbEn: 'Commands the gate watch.',
  ),
  'dvorak': LocalizedIdentity(
    titleKo: '참호 돌파자',
    titleEn: 'Trenchbreaker',
    blurbKo: '참호를 먼저 넘는 것이 그의 일이다.',
    blurbEn: 'Going over the trench first is the job.',
  ),
  'noor': LocalizedIdentity(
    titleKo: '신호 장교',
    titleEn: 'Signal Officer',
    blurbKo: '깃발 하나로 전열을 돌려세운다.',
    blurbEn: 'Turns a whole line around with one flag.',
  ),

  // ── 사이보그 ──────────────────────────────────────────────────────────
  'kestrel_unit': LocalizedIdentity(
    titleKo: '9호 프레임, 재발급',
    titleEn: 'Frame Nine, Reissued',
    blurbKo: '아홉 번째 몸으로 걸어 나온 사람.',
    blurbEn: 'Walked back out wearing a ninth body.',
  ),
  'oreb': LocalizedIdentity(
    titleKo: '하역 섀시',
    titleEn: 'Loader Chassis',
    blurbKo: '항만에서 일하다 전장으로 옮겨졌다.',
    blurbEn: 'Moved from the harbor cranes to the front line.',
  ),
  'sable': LocalizedIdentity(
    titleKo: '유령 규약',
    titleEn: 'Ghost Protocol',
    blurbKo: '기록에 남지 않는 임무만 받는다.',
    blurbEn: 'Takes only the missions that leave no record.',
  ),
  'vant_iron': LocalizedIdentity(
    titleKo: '강철 폐',
    titleEn: 'Ironlung',
    blurbKo: '숨을 기계에 맡기고 앞줄에 선다.',
    blurbEn: 'Gave breath to a machine and stands in the front rank.',
  ),
  'lumen': LocalizedIdentity(
    titleKo: '증강 야전 의무병',
    titleEn: 'Field Medic, Augmented',
    blurbKo: '고치는 손에 회로를 심었다.',
    blurbEn: 'Circuitry planted in the hands that heal.',
  ),
  'corvid': LocalizedIdentity(
    titleKo: '정찰 프레임',
    titleEn: 'Recon Frame',
    blurbKo: '정찰만 하고 절대 교전하지 않는다.',
    blurbEn: 'Scouts only. Never engages.',
  ),
};
