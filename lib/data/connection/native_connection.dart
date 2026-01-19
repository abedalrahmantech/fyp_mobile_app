import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Native/mobile/desktop connection using sqlite3 on disk.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, 'ordervista.db');
    return NativeDatabase.createInBackground(File(path));
  });
}

LazyDatabase openMemoryConnection() {
  return LazyDatabase(() async => NativeDatabase.memory());
}
