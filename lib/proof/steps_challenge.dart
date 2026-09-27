import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/models.dart';
import 'proof.dart';

bool get hasStepCounter => Platform.isAndroid || Platform.isIOS;

class StepsChallenge extends ProofChallenge {
  const StepsChallenge(this.spec);
  final StepsProof spec;

  @override
  String get title => 'Walk ${spec.steps} steps';
  @override
  String get description => 'Steps count from when you start this challenge.';
  @override
  bool get isSupportedHere => hasStepCounter;
  @override
  String get unsupportedHint => 'Do this one with your phone in your pocket.';
  @override
  Widget build(VoidCallback onPassed) => _StepsView(spec: spec, onPassed: onPassed);
}

class _StepsView extends StatefulWidget {
  const _StepsView({required this.spec, required this.onPassed});
  final StepsProof spec;
  final VoidCallback onPassed;

  @override
  State<_StepsView> createState() => _StepsViewState();
}

class _StepsViewState extends State<_StepsView> {
  StreamSubscription<StepCount>? _sub;

  /// The phone's step counter counts since boot, so remember where we started.
  int? _start;
  int _walked = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    // iPhone calls it Motion & Fitness; activityRecognition is Android only.
    final permission =
        Platform.isIOS ? Permission.sensors : Permission.activityRecognition;
    if (!await permission.request().isGranted) {
      final name = Platform.isIOS ? 'Motion & Fitness' : 'Physical activity';
      setState(() => _error = 'T.N.W.R. needs "$name" permission to count steps. '
          'Allow it in the phone settings.');
      return;
    }
    _sub = Pedometer.stepCountStream.listen(
      (count) {
        _start ??= count.steps;
        setState(() => _walked = count.steps - _start!);
        if (_walked >= widget.spec.steps) {
          _sub?.cancel();
          widget.onPassed();
        }
      },
      onError: (_) => setState(() => _error = "This phone doesn't have a step counter."),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_walked / widget.spec.steps).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.directions_walk, size: 64),
        const SizedBox(height: 12),
        if (_error != null)
          Text(_error!, textAlign: TextAlign.center)
        else ...[
          Text('$_walked / ${widget.spec.steps} steps',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress, minHeight: 10),
          const SizedBox(height: 8),
          Text(_start == null
              ? 'Start walking. The count starts with your first steps.'
              : 'Keep going!'),
        ],
      ],
    );
  }
}
