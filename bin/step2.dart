// Step 2 — one tool.
//
// A tool is a name, a sentence describing it, and a handler. The sentence is
// not documentation: it is what a model reads to decide whether to call this
// tool at all, so it is worth more care than the code under it.
import 'dart:async';
import 'dart:io';

import 'package:mcp_server/mcp_server.dart';

void main(List<String> args) async {
  const config = McpServerConfig(
    name: 'Course',
    version: '1.0.0',
    capabilities: ServerCapabilities(tools: ToolsCapability(listChanged: true)),
  );
  final server = McpServer.createServer(config);

  server.addTool(
    name: 'desk.count',
    description: 'How many people are waiting at the desk right now',
    inputSchema: const {'type': 'object', 'properties': {}},
    handler: (args) async =>
        CallToolResult(content: [TextContent(text: '{"waiting":3}')]),
  );

  final transport = McpServer.createStdioTransport().get();
  server.connect(transport);
  stderr.writeln('course step2: up, 1 tool');
  await Completer<void>().future;
}
