// Measure your stride once by walking a distance you know. Distance on Move
// then comes from your own steps instead of an estimate from your height.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic.dart';
import '../../store.dart';
import '../theme.dart';
import '../widgets.dart';

Future<void> openStride(BuildContext context, AppStore store) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StrideScreen(store: store)));

class StrideScreen extends StatefulWidget {
  const StrideScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<StrideScreen> createState() => _StrideScreenState();
}

class _StrideScreenState extends State<StrideScreen> {
  final metres = TextEditingController(text: '100');
  final steps = TextEditingController();
  double? from; // the sensor's reading when counting started; null: not counting

  AppStore get store => widget.store;
  double get _sensorNow => store.d.move.last?.c ?? 0;
  bool get _canCount => store.steps.supported && store.steps.granted && store.d.move.on;

  @override
  void dispose() {
    metres.dispose();
    steps.dispose();
    super.dispose();
  }

  void _start() => setState(() {
        from = _sensorNow;
        steps.text = '0';
      });

  void _stop() => setState(() {
        steps.text = '${(_sensorNow - from!).round()}';
        from = null;
      });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final c = store.c;
        if (from != null) steps.text = '${(_sensorNow - from!).round().clamp(0, 99999)}';
        final m = double.tryParse(metres.text.trim()) ?? 0;
        final n = int.tryParse(steps.text.trim()) ?? 0;
        final stride = from == null ? strideFrom(m, n) : null;
        final estimate = (store.d.profile?.height ?? 165) * 0.415;
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(backgroundColor: p.bg, title: const Text('Measure your stride', style: TextStyle(fontWeight: FontWeight.w700))),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            AppCard(
              child: Row(children: [
                const IconTile(Icons.straighten, size: 44),
                gap12,
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${fmt(c.strideCm)} cm a step', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Muted(c.strideMeasured ? 'Measured by you' : 'Estimated from your height. Most people are within 10–15% of this.'),
                  ]),
                ),
              ]),
            ),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('1. Pick a distance you know'),
                const Muted('100 m or more, walked at your normal pace. A running track is 400 m a lap; or measure a straight stretch of road in Google Maps (long-press the start, then “Measure distance”).'),
                gap12,
                TextField(
                  controller: metres,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'Distance', suffixText: 'metres'),
                  onChanged: (_) => setState(() {}),
                ),
              ]),
            ),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('2. Walk it and count your steps'),
                if (_canCount) ...[
                  Muted(from == null
                      ? 'Tap Start at the beginning, walk, and tap Stop at the end. Keep the phone in your pocket or hand as usual.'
                      : 'Counting. Walk to the end, then tap Stop.'),
                  gap12,
                  if (from == null)
                    GoButton('Start counting', icon: Icons.play_arrow, onPressed: _start)
                  else
                    GoButton('Stop', icon: Icons.stop, onPressed: _stop),
                  gap12,
                  const Muted('Or type in steps you counted yourself:'),
                ] else
                  const Muted('Count your steps as you walk, then type the number here. (With movement tracking on, the phone can count them for you.)'),
                gap8,
                TextField(
                  controller: steps,
                  enabled: from == null,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Steps', suffixText: 'steps'),
                  onChanged: (_) => setState(() {}),
                ),
              ]),
            ),
            if (from == null && n > 0 && m > 0)
              AppCard(
                color: stride == null ? p.medSoft : p.greenSoft,
                child: Text(
                  stride == null
                      ? 'That works out to ${fmt(m * 100 / n)} cm a step, which doesn’t look right. Walk at least 20 m and 30 steps, and check the distance.'
                      : 'Your stride: ${fmt(stride)} cm a step (the estimate from your height was ${fmt(estimate)} cm).',
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
            gap8,
            GoButton('Save my stride', big: true, icon: Icons.check, onPressed: stride == null
                ? null
                : () {
                    store.setStride(stride);
                    Navigator.pop(context);
                    toast(context, 'Stride saved: ${fmt(stride)} cm');
                  }),
            if (c.strideMeasured) ...[
              gap8,
              Center(
                child: TextButton(
                  onPressed: () {
                    store.setStride(null);
                    Navigator.pop(context);
                  },
                  child: const Text('Go back to the estimate from my height'),
                ),
              ),
            ],
          ]),
        );
      },
    );
  }
}
