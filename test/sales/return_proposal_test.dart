import 'package:flutter_test/flutter_test.dart';

import 'return_proposal_checks.dart';

void main() {
  test('return proposals match frozen source and reject invalid requests', () {
    expect(verifyReturnProposal(), greaterThanOrEqualTo(19));
  });
}
