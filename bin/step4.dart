// Step 4 — the screen, served as a resource.
//
// The screen is not code here. It is a JSON document the server hands out, so
// changing what the desk looks like does not mean rebuilding or reinstalling
// anything on the client — it means editing this document.
//
// It is read from disk on every request rather than held in memory, because a
// screen cached at boot is a screen you have to restart the server to change,
// and then the claim above stops being true.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_server/mcp_server.dart';

const _screenPath = 'ui/desk.json';

void main(List<String> args) async {
  var waiting = 3;

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
        text: File(_screenPath).readAsStringSync(),
      )
    ]),
  );

  server.addTool(
    name: 'desk.state',
    description: 'How many people are waiting',
    inputSchema: const {'type': 'object', 'properties': {}},
    handler: (args) async => CallToolResult(
      content: [TextContent(text: jsonEncode({'waiting': waiting}))],
    ),
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
      return CallToolResult(
        content: [TextContent(text: jsonEncode({'waiting': waiting}))],
      );
    },
  );

  final transport = McpServer.createStdioTransport().get();
  server.connect(transport);
  stderr.writeln('course step4: up, screen served from $_screenPath');
  await Completer<void>().future;
}
