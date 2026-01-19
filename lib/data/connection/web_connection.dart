import 'package:drift/drift.dart';
import 'package:drift/web.dart';

// Web connection using IndexedDB-backed Drift database. We avoid File System
// Access API paths by forcing IndexedDB storage.
LazyDatabase openConnection() {
  return LazyDatabase(
    () async => WebDatabase.withStorage(
      DriftWebStorage.indexedDb('ordervista'),
    ),
  );
}

LazyDatabase openMemoryConnection() {
  return LazyDatabase(
    () async => WebDatabase.withStorage(
      DriftWebStorage.indexedDb('ordervista_dev'),
    ),
  );
}
