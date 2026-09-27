import 'package:flutter_test/flutter_test.dart';
import 'package:nag_alarm/core/models.dart';
import 'package:nag_alarm/proof/approval_challenge.dart';
import 'package:nag_alarm/proof/proof.dart';

void main() {
  test('the text names the approver, the task, and includes the link', () {
    final text = approvalMessage(
      'Sam',
      'Take out the trash',
      'https://x/approve/?id=1',
    );
    expect(text, contains('Hi Sam!'));
    expect(text, contains('"Take out the trash"'));
    expect(text, endsWith('https://x/approve/?id=1'));
  });

  test('sms link keeps only dial characters and encodes spaces as %20', () {
    final uri = smsUri('+1 (555) 010-2030', 'Hi Sam! Check this', ios: false);
    expect(uri.toString(), 'sms:+15550102030?body=Hi%20Sam!%20Check%20this');
  });

  test('sms link on iPhone puts the body after "&"', () {
    final uri = smsUri('+1 (555) 010-2030', 'Hi Sam!', ios: true);
    expect(uri.toString(), 'sms:+15550102030&body=Hi%20Sam!');
  });

  test('approver settings survive saving, and the title names them', () {
    const p = ApprovalProof(approverName: 'Sam', approverPhone: '555');
    expect(ProofSpec.fromJson(p.toJson()).toJson(), p.toJson());
    expect(challengeFor(p, taskTitle: 'Dishes').title, 'Photo approved by Sam');
  });
}
