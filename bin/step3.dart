// Step 3 — the schema, and refusing.
//
// The input schema is what the caller reads to know what to send. It is not a
// guarantee: a caller can still send nonsense, so the handler checks anyway.
//
// Refusing is the part worth copying. A tool that quietly accepts a bad value
// produces a wrong number somewhere downstream and no way to find out where.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_server/mcp_server.dart';

void main(List<String> args) async {
  var waiting = 3;

  const config = McpServerConfig(
    name: 'Course',
    version: '1.0.0',
    capabilities: ServerCapabilities(tools: ToolsCapability(listChanged: true)),
  );
  final server = McpServer.createServer(config);

  server.addTool(
    name: 'desk.admit',
    description: 'Admit a number of people from the queue',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'count': {'type': 'integer', 'description': 'How many to admit, 1 or more'},
      },
      'required': ['count'],
    },
    handler: (args) async {
      final n = args['count'];
      // The schema says integer; the caller may still send anything.
      if (n is! int || n < 1) {
        return CallToolResult(
          content: [TextContent(text: 'desk.admit: count must be 1 or more')],
          isError: true,
        );
      }
      // And the desk cannot admit people who are not there.
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
  stderr.writeln('course step3: up, 1 tool that refuses');
  await Completer<void>().future;
}
