import 'package:flutter/material.dart';

import '../services/book_backend.dart';
import 'home_shell.dart';

/// Compatibility wrapper — the library UI now lives in [HomeShell].
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, this.backend});
  final BookBackend? backend;

  @override
  Widget build(BuildContext context) => HomeShell(backend: backend);
}
