import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../database.dart';

StopsDatabase constructDatabase({bool logStatements = false}) {
  if (Platform.isIOS || Platform.isAndroid) {
    final QueryExecutor executor = LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(path.join(dbFolder.path, 'busstop_database.db'));
      return NativeDatabase(file, logStatements: logStatements);
    });
    return StopsDatabase(executor);
  }
  return StopsDatabase(NativeDatabase.memory(logStatements: logStatements));
}
