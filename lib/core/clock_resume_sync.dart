import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';
import 'providers.dart';

/// Syncs the monotonic clock with the platform time whenever the app returns
/// to the foreground. The stopwatch behind the clock may stand still while
/// the device sleeps; without this, a running step would show (and on the
/// next tap store) a time without the sleep.
///
/// Wraps the whole app once (see `CycleScopeApp`), not each screen.
class ClockResumeSync extends ConsumerStatefulWidget {
  const ClockResumeSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ClockResumeSync> createState() => _ClockResumeSyncState();
}

class _ClockResumeSyncState extends ConsumerState<ClockResumeSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  Future<void> _sync() async {
    final micros = await ref.read(platformTimeProvider).readMicros();
    if (micros == null || !mounted) return;
    syncClockTo(ref.read(clockProvider), micros);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
