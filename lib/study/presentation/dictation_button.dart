import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../domain/dictation.dart';
import '../platform/speech_input.dart';

/// Speech recognition used by [DictationButton]; overridden in tests.
final speechInputProvider = Provider<SpeechInput>((ref) => SystemSpeechInput());

/// Microphone button: hold to dictate, release to stop.
///
/// With [multiline] the recognized text is inserted as a new line at the
/// cursor (one recording = one step); otherwise it is appended to the field.
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
  bool _listening = false;
  bool _pressed = false;
  String _partial = '';

  Future<void> _down() async {
    _pressed = true;
    final speech = ref.read(speechInputProvider);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _listening = true;
      _partial = '';
    });
    final ok = await speech.start(
      localeId: Localizations.localeOf(context).toLanguageTag(),
      onText: (t) {
        if (mounted) setState(() => _partial = t);
      },
    );
    if (!ok) {
      if (mounted) setState(() => _listening = false);
      messenger.showSnackBar(SnackBar(content: Text(l.dictationUnavailable)));
      return;
    }
    // Released while the recognizer was still starting.
    if (!_pressed) await _up();
  }

  Future<void> _up() async {
    _pressed = false;
    if (!_listening) return;
    final text = await ref.read(speechInputProvider).stop();
    if (!mounted) return;
    setState(() {
      _listening = false;
      _partial = '';
    });
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
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: l.holdToDictate,
          child: Listener(
            onPointerDown: (_) => _down(),
            onPointerUp: (_) => _up(),
            onPointerCancel: (_) => _up(),
            child: AnimatedContainer(
              key: const Key('dictationButton'),
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _listening ? scheme.error : scheme.primaryContainer,
              ),
              child: Icon(
                _listening ? Icons.mic : Icons.mic_none,
                color: _listening ? scheme.onError : scheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        if (_listening)
          SizedBox(
            width: 120,
            child: Text(
              _partial.isEmpty ? l.listening : _partial,
              key: const Key('dictationPartial'),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
