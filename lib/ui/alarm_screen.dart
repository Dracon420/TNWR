import 'dart:async';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../core/models.dart';
import '../proof/proof.dart';

/// Full-screen alarm. The ways out are passing the task's proofs, using one
/// of the limited snoozes, or (for a glitch) holding the emergency-off button
/// for 10 seconds and confirming.
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key, required this.controller, required this.task});

  final AppController controller;
  final NagTask task;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  int? _active;

  /// Flash at 1 Hz: well under the 3 Hz photosensitive-seizure threshold.
  Timer? _flasher;
  bool _flashOn = false;

  /// The saved task: passed proofs live there, so they survive Android
  /// closing the app while the camera or messaging app is open.
  NagTask get _live =>
      widget.controller.store.byId(widget.task.id) ?? widget.task;
  Set<int> get _passed => _live.passedProofs.toSet();

  @override
  void initState() {
    super.initState();
    // Back to a photo approval still waiting for a verdict: reopen it so it
    // keeps checking.
    final approval = widget.task.proofs.indexWhere((p) => p is ApprovalProof);
    if (approval >= 0 &&
        _live.pendingApprovalId != null &&
        !_passed.contains(approval)) {
      _active = approval;
    }
    if (widget.task.escalation.flashScreen) {
      _flasher = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => setState(() => _flashOn = !_flashOn),
      );
    }
  }

  @override
  void dispose() {
    _flasher?.cancel();
    super.dispose();
  }

  List<ProofChallenge> get _challenges => [
    for (final p in widget.task.proofs)
      challengeFor(
        p,
        taskTitle: widget.task.title,
        hold: AlarmHold(
          start: (wait) => widget.controller.holdForApproval(widget.task, wait),
          release: widget.controller.releaseApprovalHold,
          pending: () {
            final t = _live;
            return t.pendingApprovalId == null
                ? null
                : (id: t.pendingApprovalId!, url: t.pendingApprovalUrl!);
          },
          savePending: (id, url) =>
              widget.controller.savePendingApproval(widget.task, id, url),
        ),
      ),
  ];

  void _onPassed(int index) {
    setState(() => _active = null);
    // Saved first; completes the task once enough proofs have passed.
    widget.controller.proofPassed(_live, index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;
    final challenges = _challenges;

    final scheme = theme.colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _flashOn ? scheme.error : scheme.errorContainer,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _active != null
                    ? _ActiveChallenge(
                        challenge: challenges[_active!],
                        onPassed: () => _onPassed(_active!),
                        onBack: () => setState(() => _active = null),
                      )
                    : _overview(theme, task, challenges),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overview(
    ThemeData theme,
    NagTask task,
    List<ProofChallenge> challenges,
  ) {
    final onColor = _flashOn
        ? theme.colorScheme.onError
        : theme.colorScheme.onErrorContainer;
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        widget.controller.store,
      ]),
      builder: (context, _) {
        final elapsed = DateTime.now().difference(
          task.ringingSince ?? DateTime.now(),
        );
        final volume = widget.controller.current?.volume ?? 0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm, size: 72, color: onColor),
            const SizedBox(height: 12),
            Text(
              task.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                color: onColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (task.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.notes,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(color: onColor),
              ),
            ],
            const SizedBox(height: 16),
            if (widget.controller.approvalWaitLeft case final left?)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.hourglass_top),
                  title: const Text('Quiet while waiting for approval'),
                  subtitle: Text(
                    'Rings again in ${_fmt(left)} at the same '
                    'volume, unless they approve first.',
                  ),
                ),
              )
            else if (widget.controller.pausedForCall)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.phone_in_talk),
                  title: const Text('Paused for your call'),
                  subtitle: Text(
                    'Comes back after the call ends. You can still prove it '
                    'now to turn it off.',
                  ),
                ),
              )
            else
              Text(
                'Ringing for ${_fmt(elapsed)} · volume ${(volume * 100).round()}%',
                style: theme.textTheme.bodyLarge?.copyWith(color: onColor),
              ),
            const SizedBox(height: 24),
            Text(
              task.proofMode == ProofMode.all || challenges.length == 1
                  ? 'Prove it to turn this off:'
                  : 'Prove it any one of these ways:',
              style: theme.textTheme.titleMedium?.copyWith(color: onColor),
            ),
            const SizedBox(height: 8),
            for (final (i, c) in challenges.indexed)
              Card(
                child: ListTile(
                  leading: Icon(
                    _passed.contains(i)
                        ? Icons.check_circle
                        : c.isSupportedHere
                        ? Icons.play_circle
                        : Icons.phonelink_erase,
                  ),
                  title: Text(c.title),
                  subtitle: Text(
                    c.isSupportedHere ? c.description : c.unsupportedHint,
                  ),
                  enabled: c.isSupportedHere && !_passed.contains(i),
                  onTap: () => setState(() => _active = i),
                ),
              ),
            const SizedBox(height: 16),
            if (widget.controller.canSnooze(task))
              OutlinedButton.icon(
                icon: const Icon(Icons.snooze),
                label: Text(
                  'Snooze ${task.escalation.snoozeMinutes} min (comes back louder)',
                ),
                onPressed: () => widget.controller.snooze(task),
              )
            else
              Text(
                'No snoozes left.',
                style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
              ),
            const SizedBox(height: 32),
            HoldToCancelButton(
              color: onColor,
              onHeld: () => _confirmCancel(task),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmCancel(NagTask task) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber),
        title: const Text('Are you sure you wish to cancel this alarm?'),
        content: Text(
          task.repeat.kind == RepeatKind.none
              ? 'It turns off without counting "${task.title}" as done. '
                    'The reminder moves to Done; edit it to set it again.'
              : 'It turns off without counting "${task.title}" as done. '
                    'It rings again at its next repeat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep ringing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel alarm'),
          ),
        ],
      ),
    );
    if (sure == true) await widget.controller.cancelRing(_live);
  }

  static String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _ActiveChallenge extends StatelessWidget {
  const _ActiveChallenge({
    required this.challenge,
    required this.onPassed,
    required this.onBack,
  });

  final ProofChallenge challenge;
  final VoidCallback onPassed;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
                Expanded(
                  child: Text(
                    challenge.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            challenge.build(onPassed),
          ],
        ),
      ),
    );
  }
}

/// Emergency off: must be held down for [holdFor] (letting go early starts
/// over), so it can't be hit by accident or half-asleep.
class HoldToCancelButton extends StatefulWidget {
  const HoldToCancelButton({
    super.key,
    required this.onHeld,
    required this.color,
    this.holdFor = const Duration(seconds: 10),
  });

  final VoidCallback onHeld;
  final Color color;
  final Duration holdFor;

  @override
  State<HoldToCancelButton> createState() => _HoldToCancelButtonState();
}

class _HoldToCancelButtonState extends State<HoldToCancelButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: widget.holdFor)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _progress.reset();
            widget.onHeld();
          }
        });

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Raw pointer events: a hold never turns into a tap, drag or long-press
    // that another gesture could steal.
    return Listener(
      onPointerDown: (_) => _progress.forward(from: 0),
      onPointerUp: (_) => _progress.reset(),
      onPointerCancel: (_) => _progress.reset(),
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final holding = _progress.value > 0;
          final left = (widget.holdFor.inSeconds * (1 - _progress.value))
              .ceil();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: widget.color.withValues(alpha: 0.5)),
              gradient: LinearGradient(
                colors: [
                  widget.color.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
                stops: [_progress.value, _progress.value],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.power_settings_new, size: 18, color: widget.color),
                const SizedBox(width: 8),
                Text(
                  holding
                      ? 'Keep holding… $left'
                      : 'Hold ${widget.holdFor.inSeconds} s to cancel without proof',
                  style: TextStyle(color: widget.color),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
