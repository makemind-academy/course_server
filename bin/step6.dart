// Step 6 — telling the client it changed.
//
// Without this the screen has to keep asking. With it the server says so, and
// the notification carries the uri and nothing else.
//
// That is deliberate. Notifications are not ordered, so a notification that
// carried a value could arrive late and overwrite a newer one. Saying only
// "this changed" and letting the reader fetch is always correct.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_server/mcp_server.dart';

const _statePath = 'desk-state.json';

int _load() {
  final f = File(_statePath);
  if (!f.existsSync()) return 3;
  return ((jsonDecode(f.readAsStringSync()) as Map)['waiting'] as num).toInt();
}

void _save(int w) =>
    File(_statePath).writeAsStringSync(jsonEncode({'waiting': w}));

void main(List<String> args) async {
  var waiting = _load();

  const config = McpServerConfig(
    name: 'Course',
    version: '1.0.0',
    capabilities: ServerCapabilities(
      tools: ToolsCapability(listChanged: true),
      resources: ResourcesCapability(listChanged: true, subscribe: true),
    ),
  );
  final server = McpServer.createServer(config);

  // A player opens an app by reading `ui://app` first. The finished server
  // publishes its screen there as well, so the desk can be opened by the same
  // player that draws every other screen in this magazine.
  for (final uri in ['ui://app', 'ui://desk']) {
    server.addResource(
      uri: uri,
      name: 'Desk screen',
      description: 'The desk screen, served as a document',
      mimeType: 'application/json',
      handler: (requested, params) async => ReadResourceResult(contents: [
        ResourceContentInfo(
            uri: requested,
            mimeType: 'application/json',
            text: File('ui/desk.json').readAsStringSync())
      ]),
    );
  }

  server.addResource(
    uri: 'desk://waiting',
    name: 'Waiting count',
    description: 'The current number waiting, as a subscribable value',
    mimeType: 'application/json',
    handler: (uri, params) async => ReadResourceResult(contents: [
      ResourceContentInfo(
          uri: 'desk://waiting',
          mimeType: 'application/json',
          text: jsonEncode({'waiting': waiting}))
    ]),
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
      // Say that it changed. Not what it changed to.
      server.notifyResourceUpdated('desk://waiting');
      stderr.writeln('notified desk://waiting');
      return CallToolResult(
          content: [TextContent(text: jsonEncode({'waiting': waiting}))]);
    },
  );

  final transport = McpServer.createStdioTransport().get();
  server.connect(transport);
  stderr.writeln('course step6: up, subscribable (waiting=$waiting)');
  await Completer<void>().future;
}
