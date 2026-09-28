# course-server — one server, six steps

Each article in the `mcp_server` course adds one thing, and each step is a
complete server you can run on its own.

| step | file | what it adds |
| --- | --- | --- |
| 1 | `bin/step1.dart` | the server starts and answers `initialize` |
| 2 | `bin/step2.dart` | one tool |
| 3 | `bin/step3.dart` | input schema, and refusing bad input |
| 4 | `bin/step4.dart` | the screen, served as a resource |
| 5 | `bin/step5.dart` | state that survives the process |
| 6 | `bin/step6.dart` | telling the client it changed |

```bash
dart pub get
bash verify.sh          # runs all six and checks what each one claims
dart run bin/step6.dart # or any single step
```

Nothing here depends on a path outside this folder.
