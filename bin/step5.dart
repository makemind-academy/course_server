// Step 5 — state that survives the process.
//
// Up to step 4 the count lived in a variable, which means it lived exactly as
// long as the process. Pull the plug on the desk and the queue is gone.
//
// This step writes it down. The whole file is rewritten on every change, which
// is the least clever way to do it and the easiest to reason about: there is
// never a half-written record, because the write either happened or it did not.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_server/mcp_server.dart';

const _statePath = 'desk-state.json';

int _load() {
  final f = File(_statePath);
  if (!f.existsSync()) return 3;
  final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  return (m['waiting'] as num).toInt();
}

void _save(int waiting) =>
    File(_statePath).writeAsStringSync(jsonEncode({'waiting': waiting}));

void main(List<String> args) async {
  var waiting = _load();

  const config = McpServerConfig(
    name: 'Course',
    version: '1.0.0',
    capabilities: ServerCapabilities(
      tools: ToolsCapability(listChanged: true),
      resources: ResourcesCapability(listChanged: true),
    ),
  );
  final server = McpServer.createServer(config);

  server.addResource(
    uri: 'ui://desk',
    name: 'Desk screen',
    description: 'The desk screen, served as a document',
    mimeType: 'application/json',
    handler: (uri, params) async => ReadResourceResult(contents: [
      ResourceContentInfo(
          uri: 'ui://desk',
          mimeType: 'application/json',
          text: File('ui/desk.json').readAsStringSync())
    ]),
  );

  server.addTool(
    name: 'desk.state',
    description: 'How many people are waiting',
    inputSchema: const {'type': 'object', 'properties': {}},
    handler: (args) async => CallToolResult(
        content: [TextContent(text: jsonEncode({'waiting': waiting}))]),
  );

  server.addTool(
    name: 'desk.admit',
    description: 'Admit a number of people from the queue',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'count': {'type': 'integer'},
      },
      'required': ['count'],
    },
    handler: (args) async {
      final n = args['count'];
      // Step 3 drew this distinction and later steps keep it: a value that is
      // never valid reads differently from one that is only invalid now.
      if (n is! int || n < 1) {
        return CallToolResult(
          content: [TextContent(text: 'desk.admit: count must be 1 or more')],
          isError: true,
        );
      }
      if (n > waiting) {
        return CallToolResult(
          content: [TextContent(text: 'only $waiting waiting')],
          isError: true,
        );
      }
      waiting -= n;
      _save(waiting);
      return CallToolResult(
          content: [TextContent(text: jsonEncode({'waiting': waiting}))]);
    },
  );

  final transport = McpServer.createStdioTransport().get();
  server.connect(transport);
  stderr.writeln('course step5: up, state in $_statePath (waiting=$waiting)');
  await Completer<void>().future;
}
