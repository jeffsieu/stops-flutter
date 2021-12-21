import 'package:drift/web.dart';

import '../database.dart';

StopsDatabase constructDatabase({bool logStatements = false}) {
  return StopsDatabase(WebDatabase('db', logStatements: logStatements));
}
