// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:test_core/src/util/io.dart';

void main() {
  test('isAiAgent detects AI coding agents from environment variables', () {
    expect(isAiAgent(<String, String>{}), isFalse);

    expect(isAiAgent(<String, String>{'CLAUDECODE': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'CLAUDE_CODE': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'CLAUDE_CODE_IS_COWORK': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'ANTIGRAVITY_AGENT': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'GEMINI_AGENT': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'GEMINI_CLI': '1'}), isTrue);

    expect(isAiAgent(<String, String>{'TERM_PROGRAM': 'cursor'}), isFalse);
    expect(isAiAgent(<String, String>{'CURSOR_TRACE_ID': 'abc'}), isFalse);
    expect(isAiAgent(<String, String>{'CURSOR_APP_VERSION': '1'}), isFalse);
    expect(isAiAgent(<String, String>{'CURSOR_AGENT': ''}), isFalse);
    expect(isAiAgent(<String, String>{'CURSOR_AGENT': '   '}), isFalse);
    expect(isAiAgent(<String, String>{'CURSOR_AGENT': '0'}), isFalse);
    expect(isAiAgent(<String, String>{'CURSOR_AGENT': 'false'}), isFalse);
    expect(isAiAgent(<String, String>{'CURSOR_AGENT': 'FALSE'}), isFalse);
    expect(isAiAgent(<String, String>{'CURSOR_AGENT': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'CURSOR_AGENT': 'true'}), isTrue);
    expect(
      isAiAgent(<String, String>{'CURSOR_EXTENSION_HOST_ROLE': 'agent-exec'}),
      isTrue,
    );

    expect(isAiAgent(<String, String>{'COPILOT_CLI': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'GITHUB_COPILOT': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'AIDER': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'AIDER_COMMAND': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'DEVIN': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'DEVIN_WORKSPACE_ID': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'AMP_CURRENT_THREAD_ID': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'AUGMENT_AGENT': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'CODEX_CI': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'CODEX_SANDBOX': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'CODEX_THREAD_ID': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'OPENCODE': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'OPENCODE_CLIENT': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'PI_CODING_AGENT': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'REPL_ID': '1'}), isTrue);

    expect(isAiAgent(<String, String>{'SWE_AGENT': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'AI_AGENT': ''}), isFalse);
    expect(isAiAgent(<String, String>{'AI_AGENT': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'AI_AGENT': 'MyCustomAgent'}), isTrue);
    expect(isAiAgent(<String, String>{'AGENT': ''}), isFalse);
    expect(isAiAgent(<String, String>{'AGENT': '1'}), isTrue);
    expect(isAiAgent(<String, String>{'AGENT': 'MyCustomAgent'}), isTrue);
  });
}
