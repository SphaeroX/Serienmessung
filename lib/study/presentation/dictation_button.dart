import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../domain/dictation.dart';
import '../platform/speech_input.dart';

/// Speech recognition used by [DictationButton]; overridden in tests.
final speechInputProvider = Provider<SpeechInput>((ref) => SystemSpeechInput());

/// Wide push-to-talk button: hold to dictate, release to stop.
///
/// Placed below the text field (not beside it) so it is not hit by accident
/// while scrolling. With [multiline] the recognized text is inserted as a new
/// line at the cursor (one recording = one step); otherwise it is appended to
/// the field.
///
/// Recognizer calls are queued: a release while the recognizer is still
/// starting stops it once it runs, and a new press waits until the previous
/// session has delivered its result (the platform recognizer is busy until
/// then).
class DictationButton extends ConsumerStatefulWidget {
  const DictationButton({
    super.key,
    required this.controller,
    this.multiline = true,
    this.onInserted,
  });

  final TextEditingController controller;
  final bool multiline;
  final VoidCallback? onInserted;

  @override
  ConsumerState<DictationButton> createState() => _DictationButtonState();
}

class _DictationButtonState extends ConsumerState<DictationButton> {
  /// Shown as listening while pressed.
  bool _pressed = false;

  /// A recognizer session is running and must be stopped.
  bool _active = false;
  String _partial = '';
  Future<void> _queue = Future.value();

  void _enqueue(Future<void> Function() op) {
    _queue = _queue.then((_) => op()).catchError((Object _) {});
  }

  void _down() {
    if (_pressed) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final localeId = Localizations.localeOf(context).toLanguageTag();
    setState(() {
      _pressed = true;
      _partial = '';
    });
    _enqueue(() => _start(localeId, l, messenger));
  }

  void _up() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    _enqueue(_finish);
  }

  Future<void> _start(
    String localeId,
    AppLocalizations l,
    ScaffoldMessengerState messenger,
  ) async {
    // Released before it was our turn: nothing to record.
    if (!_pressed || !mounted) return;
    final ok = await ref
        .read(speechInputProvider)
        .start(
          localeId: localeId,
          onText: (t) {
            if (mounted && _pressed) setState(() => _partial = t);
          },
        );
    if (!ok) {
      if (mounted) setState(() => _pressed = false);
      messenger.showSnackBar(SnackBar(content: Text(l.dictationUnavailable)));
      return;
    }
    _active = true;
  }

  Future<void> _finish() async {
    if (!_active) return;
    _active = false;
    final text = await ref.read(speechInputProvider).stop();
    if (!mounted) return;
    if (!_pressed) setState(() => _partial = '');
    final c = widget.controller;
    final edit = widget.multiline
        ? insertDictatedLine(
            c.text,
            c.selection.isValid ? c.selection.baseOffset : -1,
            text,
          )
        : appendDictatedWords(c.text, text);
    c.value = TextEditingValue(
      text: edit.text,
      selection: TextSelection.collapsed(offset: edit.cursor),
    );
    widget.onInserted?.call();
  }

  @override
  void dispose() {
    if (_active) {
      _active = false;
      ref.read(speechInputProvider).stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final listening = _pressed;
    final fg = listening ? scheme.onError : scheme.onPrimaryContainer;
    return Listener(
      onPointerDown: (_) => _down(),
      onPointerUp: (_) => _up(),
      onPointerCancel: (_) => _up(),
      child: AnimatedContainer(
        key: const Key('dictationButton'),
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: listening ? scheme.error : scheme.primaryContainer,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(listening ? Icons.mic : Icons.mic_none, color: fg, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                listening
                    ? (_partial.isEmpty ? l.listening : _partial)
                    : l.holdToDictate,
                key: listening ? const Key('dictationPartial') : null,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.bold,
                  fontStyle: listening ? FontStyle.italic : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
