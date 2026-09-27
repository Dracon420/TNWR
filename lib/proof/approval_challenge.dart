import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/cloud.dart';
import '../core/models.dart';
import 'proof.dart';

/// Needs a camera and the online backend (supabase/functions/approval*).
bool get canRequestApproval => (Platform.isAndroid || Platform.isIOS) && Cloud.configured;

/// Text sent to the approver.
String approvalMessage(String approverName, String taskTitle, String url) =>
    'Hi $approverName! T.N.W.R. says "$taskTitle" is done. '
    'Please check my photo and tap Approve or Not done: $url';

/// sms: link that opens the messaging app with the text filled in.
Uri smsUri(String phone, String body, {bool? ios}) {
  final number = phone.replaceAll(RegExp(r'[^\d+]'), '');
  // Explicit %20 encoding: some messaging apps show "+" for spaces.
  final text = Uri.encodeComponent(body);
  // Messages on iPhone wants "&body=" right after the number.
  if (ios ?? Platform.isIOS) return Uri.parse('sms:$number&body=$text');
  return Uri(scheme: 'sms', path: number, query: 'body=$text');
}

class ApprovalChallenge extends ProofChallenge {
  const ApprovalChallenge(this.spec, {this.taskTitle = '', this.hold});
  final ApprovalProof spec;
  final String taskTitle;
  final AlarmHold? hold;

  @override
  String get title => 'Photo approved by ${spec.approverName}';
  @override
  String get description =>
      'Take a photo; ${spec.approverName} gets a link to approve it.';
  @override
  bool get isSupportedHere => canRequestApproval;
  @override
  String get unsupportedHint => Cloud.configured
      ? 'Do this one on your phone.'
      : 'Needs the online setup (see docs/ALEXA_SETUP.md, part A).';
  @override
  Widget build(VoidCallback onPassed) =>
      _ApprovalView(
          spec: spec, taskTitle: taskTitle, hold: hold, onPassed: onPassed);
}

/// A request waiting for a verdict, kept across rebuilds of the alarm screen.
class _Pending {
  _Pending(this.id, this.url);
  final String id;
  final String url;
}

final _pendingByApprover = <String, _Pending>{};

class _ApprovalView extends StatefulWidget {
  const _ApprovalView(
      {required this.spec,
      required this.taskTitle,
      required this.hold,
      required this.onPassed});
  final ApprovalProof spec;
  final String taskTitle;
  final AlarmHold? hold;
  final VoidCallback onPassed;

  @override
  State<_ApprovalView> createState() => _ApprovalViewState();
}

class _ApprovalViewState extends State<_ApprovalView> {
  late _Pending? _pending = _restorePending();

  _Pending? _restorePending() {
    final saved = widget.hold?.pending?.call();
    return saved != null
        ? _Pending(saved.id, saved.url)
        : _pendingByApprover[widget.spec.approverName];
  }

  Future<void> _savePending(_Pending? p) async {
    if (p == null) {
      _pendingByApprover.remove(_name);
    } else {
      _pendingByApprover[_name] = p;
    }
    await widget.hold?.savePending?.call(p?.id, p?.url);
  }
  String? _status;
  bool _busy = false;
  Timer? _poll;

  String get _name => widget.spec.approverName;

  @override
  void initState() {
    super.initState();
    if (_pending != null) _startPolling();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _takeAndSend() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final shot = await ImagePicker().pickImage(
          source: ImageSource.camera, maxWidth: 1024, imageQuality: 75);
      if (shot == null) return;
      if (!await Cloud.ensureReady()) throw "Can't reach the server.";
      final res = await Cloud.client.functions.invoke('approval-create', body: {
        'title': widget.taskTitle,
        'approverName': _name,
        'photo': base64Encode(await File(shot.path).readAsBytes()),
      });
      final data = res.data as Map;
      final pending = _Pending(data['id'] as String, data['url'] as String);
      await _savePending(pending);
      setState(() => _pending = pending);
      await _send();
      // Quiet while they look; rings again at the same volume if no answer.
      await widget.hold?.start(Duration(minutes: widget.spec.waitMinutes));
      _startPolling();
    } catch (e) {
      setState(() => _status = "Couldn't send the photo: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens a text to the approver, or the share sheet if there's no number.
  Future<void> _send({bool shareSheet = false}) async {
    final text = approvalMessage(_name, widget.taskTitle, _pending!.url);
    final phone = widget.spec.approverPhone;
    if (!shareSheet && phone.isNotEmpty &&
        await launchUrl(smsUri(phone, text))) {
      return;
    }
    await SharePlus.instance.share(ShareParams(text: text));
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check());
    _check();
  }

  Future<void> _check() async {
    final pending = _pending;
    if (pending == null) return;
    try {
      final row = await Cloud.client
          .from('photo_approvals')
          .select('status, note')
          .eq('id', pending.id)
          .single();
      switch (row['status']) {
        case 'approved':
          _poll?.cancel();
          await _savePending(null);
          widget.onPassed();
        case 'rejected':
          _poll?.cancel();
          await _savePending(null);
          await widget.hold?.release();
          final note = row['note'] as String?;
          setState(() {
            _pending = null;
            _status = '$_name says it\'s not done'
                '${note == null || note.isEmpty ? '.' : ': "$note"'} '
                'Finish it and send a new photo.';
          });
      }
    } catch (_) {
      // Offline for a moment; the next poll retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(pending == null ? Icons.photo_camera : Icons.hourglass_top, size: 64),
        const SizedBox(height: 12),
        if (pending == null)
          FilledButton.icon(
            icon: const Icon(Icons.photo_camera),
            label: Text('Take photo and send to $_name'),
            onPressed: _busy ? null : _takeAndSend,
          )
        else ...[
          Text('Waiting for $_name to approve…',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
              'The alarm is quiet for up to ${widget.spec.waitMinutes} min while '
              'they look, then rings again at the same volume. This closes '
              'by itself once they approve.',
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.sms),
              label: const Text('Send again'),
              onPressed: _send,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Send another way'),
              onPressed: () => _send(shareSheet: true),
            ),
            TextButton(
              onPressed: _busy ? null : _takeAndSend,
              child: const Text('Retake photo'),
            ),
          ]),
        ],
        if (_busy)
          const Padding(
              padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
        if (_status != null) ...[
          const SizedBox(height: 12),
          Text(_status!, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
