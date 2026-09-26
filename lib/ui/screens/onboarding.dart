// First-run setup in three short screens, and the same screens reopened one
// at a time from Me: name and photo, what you eat, what's in your kitchen.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/catalog.dart';
import '../../models.dart';
import '../../store.dart';
import '../theme.dart';
import '../widgets.dart';

enum SetupMode { onboard, profile, pref, kitchen }

Future<void> openSetup(BuildContext context, AppStore store, SetupMode mode) =>
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => SetupScreen(store: store, mode: mode)));

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.store, required this.mode});
  final AppStore store;
  final SetupMode mode;
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late int step = switch (widget.mode) { SetupMode.kitchen => 2, SetupMode.pref => 1, _ => 0 };
  late final name = TextEditingController(text: widget.store.d.me.name);
  late String photo = widget.store.d.me.photo;
  late String pref = widget.store.d.settings.dietPref;
  late Set<String> have = widget.store.c.pantry;
  String? nameError;

  bool get onboarding => widget.mode == SetupMode.onboard;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() => photo = 'data:image/jpeg;base64,${base64Encode(bytes)}');
    } catch (_) {
      if (mounted) toast(context, 'Couldn’t read that photo');
    }
  }

  void _photoMenu() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Text('📷', style: TextStyle(fontSize: 22)), title: const Text('Take a photo'), onTap: () {
              Navigator.pop(ctx);
              _pickPhoto(ImageSource.camera);
            }),
            ListTile(leading: const Text('🖼️', style: TextStyle(fontSize: 22)), title: const Text('Choose from gallery'), onTap: () {
              Navigator.pop(ctx);
              _pickPhoto(ImageSource.gallery);
            }),
            if (photo.isNotEmpty)
              ListTile(leading: const Text('🗑️', style: TextStyle(fontSize: 22)), title: const Text('Remove photo'), onTap: () {
                Navigator.pop(ctx);
                setState(() => photo = '');
              }),
          ]),
        ),
      );

  void _next() {
    final store = widget.store;
    if (step == 0 && onboarding && name.text.trim().isEmpty) {
      // Shown under the box, not as a pop-up that would cover the button.
      setState(() => nameError = 'Add your name, or anything you like to be called');
      return;
    }
    if (onboarding && step < 2) {
      setState(() => step++);
      return;
    }
    switch (widget.mode) {
      case SetupMode.onboard:
        store.finishOnboarding(name: name.text.trim(), photo: photo, pref: pref, pantry: have.toList());
      case SetupMode.profile:
        store.setNamePhoto(name.text.trim(), photo);
      case SetupMode.pref:
        store.setDietPref(pref);
      case SetupMode.kitchen:
        store.setPantry(have.toList());
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final titles = [onboarding ? 'Welcome! 👋' : 'Your profile', 'What do you eat?', 'What’s in your kitchen?'];
    return PopScope(
      canPop: !onboarding || widget.store.d.me.onboarded,
      child: Scaffold(
        backgroundColor: p.bg,
        body: Column(children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(gradient: heroGradient(p)),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (!onboarding || widget.store.d.me.onboarded) ...[
                  Material(
                    color: Colors.white.withValues(alpha: .16),
                    shape: const CircleBorder(),
                    child: IconButton(tooltip: 'Close', icon: const Icon(Icons.close, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
                  ),
                  gap12,
                ] else if (step > 0) ...[
                  Material(
                    color: Colors.white.withValues(alpha: .16),
                    shape: const CircleBorder(),
                    child: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18), onPressed: () => setState(() => step--)),
                  ),
                  gap12,
                ],
                Expanded(child: Text(titles[step], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))),
              ]),
              if (onboarding) ...[
                gap12,
                Row(children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 24,
                      height: 5,
                      decoration: BoxDecoration(color: i == step ? Colors.white : Colors.white30, borderRadius: BorderRadius.circular(99)),
                    ),
                ]),
              ],
            ]),
          ),
          Expanded(child: [_nameStep, _prefStep, _kitchenStep][step](p)),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
            child: GoButton(!onboarding ? 'Save' : step == 2 ? 'Done, let’s go' : 'Next', big: true, onPressed: _next),
          ),
        ]),
      ),
    );
  }

  Widget _nameStep(Pal p) => ListView(padding: const EdgeInsets.all(16), children: [
        gap8,
        Center(
          child: GestureDetector(
            onTap: _photoMenu,
            child: Stack(clipBehavior: Clip.none, children: [
              Avatar(me: Me(name: name.text, photo: photo), size: 120, border: 0),
              Positioned(
                right: 0,
                bottom: 4,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: Pal.goSolid, shape: BoxShape.circle, border: Border.all(color: p.bg, width: 3)),
                  child: const Center(child: Text('📷', style: TextStyle(fontSize: 17))),
                ),
              ),
            ]),
          ),
        ),
        gap8,
        Muted(photo.isEmpty ? 'Tap to add a photo (optional)' : 'Tap the photo to change it', align: TextAlign.center),
        gap16,
        Text('What should we call you?', style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
        gap8,
        TextField(
          controller: name,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: 'Your name', counterText: '', errorText: nameError),
          onChanged: (_) => setState(() => nameError = null),
        ),
      ]);

  Widget _prefStep(Pal p) => ListView(padding: const EdgeInsets.all(16), children: [
        const Muted('So we never suggest food you don’t eat.', size: 15),
        gap12,
        for (final d in dietPrefs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: pref == d.id ? p.brandSoft : p.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: pref == d.id ? p.brand : p.line, width: 2)),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => pref = d.id),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    EmojiBox(d.emoji, size: 50, bg: p.greenSoft, radius: 16),
                    gap16,
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Muted(d.desc),
                      ]),
                    ),
                    if (pref == d.id) Icon(Icons.check_circle, color: p.brand),
                  ]),
                ),
              ),
            ),
          ),
      ]);

  Widget _kitchenStep(Pal p) => ListView(padding: const EdgeInsets.all(16), children: [
        const Muted('We’ve ticked what most homes have. Untick what you don’t have and tick anything else. Plans will only use these.', size: 15),
        gap12,
        Wrap(spacing: 8, runSpacing: 8, children: [
          SoftButton('Typical kitchen', slim: true, onPressed: () => setState(() => have = {...defaultPantry})),
          SoftButton('Clear all', slim: true, onPressed: () => setState(() => have = {})),
        ]),
        for (final g in pantryGroups) ...[
          Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final i in g.items)
              FilterChip(
                label: Text('${i.emoji} ${i.label}'),
                selected: have.contains(i.id),
                showCheckmark: true,
                checkmarkColor: p.green,
                selectedColor: p.greenSoft,
                side: BorderSide(color: have.contains(i.id) ? p.green : p.line, width: 1.5),
                shape: const StadiumBorder(),
                onSelected: (v) => setState(() => v ? have.add(i.id) : have.remove(i.id)),
              ),
          ]),
        ],
      ]);
}
