import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment;

import '../core/spline.dart';

/// 3점 조명 리그의 2D 근사.
///
/// 실시간 3D 의 룩을 2D 에서 흉내 낼 때 결정적인 것은 조명이 장면 전체에서
/// 일관되게 유지되는 것이다. 모든 파츠가 같은 [LightRig] 를 참조하므로
/// 광원 방향을 하나 바꾸면 캐릭터·무기·배경 그림자가 동시에 따라 움직인다.
class LightRig {
  LightRig({
    Offset keyDir = const Offset(0.55, 0.83),
    this.keyColor = const Color(0xFFFFF1D8),
    this.keyIntensity = 1.0,
    Offset rimDir = const Offset(-0.72, -0.69),
    this.rimColor = const Color(0xFF8FC7FF),
    this.rimIntensity = 1.0,
    this.ambient = const Color(0xFF2A3550),
    this.bounce = const Color(0xFF5B4A38),
    this.exposure = 1.0,
  })  : keyDir = keyDir.normalized(),
        rimDir = rimDir.normalized();

  /// 빛이 진행하는 방향(광원 → 피사체).
  final Offset keyDir;
  final Color keyColor;
  final double keyIntensity;

  /// 백라이트가 진행하는 방향.
  final Offset rimDir;
  final Color rimColor;
  final double rimIntensity;

  /// 하늘/환경광. 그림자 쪽 색조를 결정한다.
  final Color ambient;

  /// 바닥 반사광. 아래쪽에서 올라오는 따뜻한 빛.
  final Color bounce;

  final double exposure;

  /// 광원이 있는 쪽(= -keyDir)의 정렬. 그라디언트 시작점으로 쓴다.
  Alignment get keyAlign => Alignment(-keyDir.dx, -keyDir.dy);

  Alignment get rimAlign => Alignment(-rimDir.dx, -rimDir.dy);

  /// 그림자가 드리우는 방향(지면 투영).
  Offset get shadowDir => Offset(keyDir.dx, keyDir.dy.abs()).normalized();

  LightRig copyWith({
    Offset? keyDir,
    Color? keyColor,
    double? keyIntensity,
    Offset? rimDir,
    Color? rimColor,
    double? rimIntensity,
    Color? ambient,
    Color? bounce,
    double? exposure,
  }) =>
      LightRig(
        keyDir: keyDir ?? this.keyDir,
        keyColor: keyColor ?? this.keyColor,
        keyIntensity: keyIntensity ?? this.keyIntensity,
        rimDir: rimDir ?? this.rimDir,
        rimColor: rimColor ?? this.rimColor,
        rimIntensity: rimIntensity ?? this.rimIntensity,
        ambient: ambient ?? this.ambient,
        bounce: bounce ?? this.bounce,
        exposure: exposure ?? this.exposure,
      );

  /// 시각(0..1)에 따른 프리셋. 낮/황혼/밤/지하 던전.
  static LightRig preset(int i) {
    switch (i % 4) {
      case 0: // 정오의 야외
        return LightRig(
          keyDir: const Offset(0.5, 0.86),
          keyColor: const Color(0xFFFFF4DC),
          keyIntensity: 1.05,
          rimDir: const Offset(-0.7, -0.71),
          rimColor: const Color(0xFF9CD2FF),
          rimIntensity: 0.85,
          ambient: const Color(0xFF31415F),
          bounce: const Color(0xFF6F6A4E),
        );
      case 1: // 황혼
        return LightRig(
          keyDir: const Offset(0.82, 0.57),
          keyColor: const Color(0xFFFFB06A),
          keyIntensity: 1.15,
          rimDir: const Offset(-0.6, -0.8),
          rimColor: const Color(0xFF7FA8FF),
          rimIntensity: 1.1,
          ambient: const Color(0xFF3B2B52),
          bounce: const Color(0xFF7A4630),
        );
      case 2: // 달빛
        return LightRig(
          keyDir: const Offset(0.45, 0.89),
          keyColor: const Color(0xFFB9D4FF),
          keyIntensity: 0.8,
          rimDir: const Offset(-0.75, -0.66),
          rimColor: const Color(0xFFCFE4FF),
          rimIntensity: 1.25,
          ambient: const Color(0xFF141E38),
          bounce: const Color(0xFF25344F),
          exposure: 0.92,
        );
      default: // 던전 화톳불
        return LightRig(
          keyDir: const Offset(0.35, 0.94),
          keyColor: const Color(0xFFFF9A45),
          keyIntensity: 1.2,
          rimDir: const Offset(-0.8, -0.6),
          rimColor: const Color(0xFF56E0C8),
          rimIntensity: 1.0,
          ambient: const Color(0xFF1B1526),
          bounce: const Color(0xFF57210F),
          exposure: 1.05,
        );
    }
  }

  /// 리그 전체를 같은 각도로 회전한다.
  ///
  /// 캔버스를 회전시켜 파츠를 그릴 때(머리·무기처럼 로컬 좌표가 편한 파츠)
  /// 조명까지 함께 돌아가면 죽음 애니메이션처럼 몸이 크게 기운 순간 광원이
  /// 캐릭터를 따라 도는 모순이 생긴다. 캔버스 회전각의 역수로 리그를 돌려
  /// 넘기면 조명이 월드에 고정된 채 유지된다.
  LightRig rotated(double radians) {
    final c = math.cos(radians), s = math.sin(radians);
    Offset rot(Offset v) => Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
    return copyWith(keyDir: rot(keyDir), rimDir: rot(rimDir));
  }

  /// 키라이트를 각도로 회전한 리그. UI 슬라이더가 이걸 호출한다.
  LightRig rotatedKey(double radians) {
    final a = math.atan2(keyDir.dy, keyDir.dx) + radians;
    return copyWith(
      keyDir: Offset(math.cos(a), math.sin(a)),
      rimDir: Offset(math.cos(a + math.pi * 0.86), math.sin(a + math.pi * 0.86)),
    );
  }
}
