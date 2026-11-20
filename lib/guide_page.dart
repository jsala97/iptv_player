import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'epg.dart';
import 'iptv_source.dart';
import 'settings.dart';

String _hhmm(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

DateTime _slot(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day, l.hour, l.minute < 30 ? 0 : 30)
      .toUtc();
}

class GuidePage extends StatefulWidget {
  final List<Channel> channels;
  final Epg epg;
  final void Function(Channel, List<Channel>) onPlay;
  final VoidCallback onClose;

  const GuidePage({
    super.key,
    required this.channels,
    required this.epg,
    required this.onPlay,
    required this.onClose,
  });

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  static const _hours = 3;
  static const _nameW = 200.0;
  DateTime _start = _slot(DateTime.now().subtract(const Duration(minutes: 30)));

  void _shift(int hours) {
    setState(() => _start = _start.add(Duration(hours: hours)));
  }

  void _goNow() {
    setState(() {
      _start = _slot(DateTime.now().subtract(const Duration(minutes: 30)));
    });
  }

  // Barra superior: volver, título y botones de hora.
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver a los canales',
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onClose,
          ),
          const SizedBox(width: 8),
          const Text('Guía', style: TextStyle(fontSize: 20)),
          const Spacer(),
          IconButton(
            tooltip: 'Una hora antes',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shift(-1),
          ),
          TextButton(onPressed: _goNow, child: const Text('Ahora')),
          IconButton(
            tooltip: 'Una hora después',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shift(1),
          ),
        ],
      ),
    );
  }

  // Fila superior con las horas.
  Widget _header(double gridW) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const SizedBox(width: _nameW),
          SizedBox(
            width: gridW,
            child: Stack(
              children: [
                for (var i = 0; i < _hours * 2; i++)
                  Positioned(
                    left: i * gridW / (_hours * 2) + 4,
                    top: 8,
                    child: Text(
                      _hhmm(_start.add(Duration(minutes: 30 * i))),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Un programa dentro de la fila de un canal.
    Widget _block(
    Channel ch,
    Programme p,
    double Function(DateTime) x,
    DateTime nowUtc,
    ColorScheme cs,
  ) {
    final isNow = !p.start.isAfter(nowUtc) && p.end.isAfter(nowUtc);
    return Positioned(
      left: x(p.start),
      width: x(p.end) - x(p.start) - 2,
      top: 4,
      bottom: 4,
      child: Tooltip(
        message: p.desc.isEmpty ? p.title : '${p.title}\n${p.desc}',
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: isNow
              ? const Color(0xFFffffff).withValues(alpha: 0.35)
              //? cs.primary.withValues(alpha: 0.35)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.onPlay(ch, widget.channels),
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Una fila completa: nombre del canal + sus programas.
  Widget _row(
    Channel ch,
    double gridW,
    double Function(DateTime) x,
    DateTime nowUtc,
    DateTime end,
    ColorScheme cs,
  ) {
    final progs = widget.epg
        .programmesFor(ch)
        .where((p) => p.end.isAfter(_start) && p.start.isBefore(end))
        .toList();
    return Row(
      children: [
        SizedBox(
          width: _nameW,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              displayName(ch.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(
          width: gridW,
          child: Stack(
            children: [
              for (final p in progs)
                if (x(p.end) - x(p.start) > 4) _block(ch, p, x, nowUtc, cs),
            ],
          ),
        ),
      ],
    );
  }

  // La parrilla: cabecera de horas, filas y línea de "ahora".
  Widget _grid() {
    final cs = Theme.of(context).colorScheme;
    final end = _start.add(const Duration(hours: _hours));
    final nowUtc = DateTime.now().toUtc();

    return LayoutBuilder(
      builder: (context, box) {
        final gridW = box.maxWidth - _nameW;
        const totalMin = _hours * 60.0;
        double x(DateTime t) {
          final frac = t.difference(_start).inSeconds / 60 / totalMin;
          return frac.clamp(0.0, 1.0) * gridW;
        }

        final showNow = nowUtc.isAfter(_start) && nowUtc.isBefore(end);

        return Stack(
          children: [
            Column(
              children: [
                _header(gridW),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.channels.length,
                    itemExtent: 56,
                    itemBuilder: (context, i) => _row(
                      widget.channels[i],
                      gridW,
                      x,
                      nowUtc,
                      end,
                      cs,
                    ),
                  ),
                ),
              ],
            ),
            if (showNow)
              Positioned(
                left: _nameW + x(nowUtc),
                top: 32,
                bottom: 0,
                width: 2,
                child: IgnorePointer(
                  child: ColoredBox(color: cs.primary),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _topBar(),
        Expanded(child: _grid()),
      ],
    );

    // Esc cierra la guía.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Focus(autofocus: true, child: content),
    );
  }
}