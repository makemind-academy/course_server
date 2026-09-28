// Step 1 — the server starts.
//
// Nothing is registered yet. The only thing this proves is that a client can
// connect and get an answer to `initialize`, which is the handshake every
// later step depends on.
//
// The one thing to notice is where the diagnostics go. In stdio mode stdout
// carries JSON-RPC and nothing else, so a single stray `print` corrupts the
// stream. Everything human-readable goes to stderr instead.
import 'dart:async';
import 'dart:io';

import 'package:mcp_server/mcp_server.dart';

void main(List<String> args) async {
  const config = McpServerConfig(
    name: 'Course',
    version: '1.0.0',
    capabilities: ServerCapabilities(),
  );
  final server = McpServer.createServer(config);

  final transport = McpServer.createStdioTransport().get();
  server.connect(transport);

  stderr.writeln('course step1: up, nothing registered');
  await Completer<void>().future;
}
