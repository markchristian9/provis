import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/creature.dart';
import '../core/palette.dart';

/// 카드 안에 캐릭터 전신을 그리는 페인터.
///
/// 스테이지와 완전히 같은 [Artist.paint] 를 부르되 [detail] 만 낮춘다.
/// 썸네일용 별도 에셋이 없으므로 원본과 어긋날 일이 구조적으로 없다.
class ArtistPortrait extends CustomPainter {
  const ArtistPortrait(this.artist, {this.detail = 0.34, this.time = 0});

  final Artist artist;
  final double detail;
  final double time;

  @override
  void paint(Canvas c, Size size) {
    final rect = Offset.zero & size;
    final mood = artist.moodSky;

    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            mood[0].darken(0.2),
            mood.length > 1 ? mood[1] : mood[0],
            mood.last.darken(0.35),
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(rect),
    );

    // 인물 뒤의 후광. 어두운 캐릭터도 카드 안에서는 실루엣이 살아야 한다.
    c.drawCircle(
      Offset(size.width * 0.5, size.height * 0.42),
      size.width * 0.62,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [artist.accent.fade(0.20), artist.accent.fade(0.0)],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.5, size.height * 0.42),
            radius: size.width * 0.62,
          ),
        ),
    );

    final f = artist.framing;
    final scale =
        math.min(size.width / f.width, size.height * 0.92 / f.height);

    c.save();
    c.clipRect(rect);
    c.translate(size.width * 0.5, size.height * 0.96);
    c.scale(scale);
    c.translate(-f.center.dx, -f.bottom);
    artist.paint(c, time, detail: detail);
    c.restore();

    // 이름표가 얹힐 자리를 어둡게 눌러 준다.
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x00000000),
            const Color(0xE605070C),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant ArtistPortrait old) =>
      old.artist != artist || old.time != time || old.detail != detail;
}

/// 선택 스트립에 놓이는 카드 한 장.
class ArtistCard extends StatefulWidget {
  const ArtistCard({
    super.key,
    required this.artist,
    required this.selected,
    required this.onTap,
    this.width = 118,
    this.height = 158,
  });

  final Artist artist;
  final bool selected;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  State<ArtistCard> createState() => _ArtistCardState();
}

class _ArtistCardState extends State<ArtistCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.artist;
    final on = widget.selected;
    final lift = on ? 8.0 : (_hover ? 4.0 : 0.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height,
          transform: Matrix4.translationValues(0, -lift, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: on
                  ? a.accent
                  : (_hover ? a.accent.fade(0.55) : const Color(0xFF25303F)),
              width: on ? 2.2 : 1.2,
            ),
            boxShadow: [
              if (on)
                BoxShadow(
                  color: a.accent.fade(0.45),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              BoxShadow(
                color: const Color(0xCC000000),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(painter: ArtistPortrait(a)),
                ),
                if (!on)
                  ColoredBox(
                    color: const Color(0xFF05070C).withValues(
                      alpha: _hover ? 0.10 : 0.30,
                    ),
                  ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        a.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: on ? a.accent : const Color(0xFFD5DDEA),
                          fontSize: 12.5,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _tag(a),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8C9AAD),
                          fontSize: 9,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                if (a.sex != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xAA05070C),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: a.accent.fade(0.5)),
                      ),
                      child: Text(
                        a.sex == Sex.male ? '♂' : '♀',
                        style: TextStyle(
                          color: a.accent,
                          fontSize: 11,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _tag(Artist a) {
    final parts = a.title.split(' ');
    return parts.length > 2 ? parts.take(2).join(' ') : a.title;
  }
}
