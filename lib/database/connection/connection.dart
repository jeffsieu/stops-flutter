export 'unsupported.dart'
    if (dart.library.js) 'web.dart'
    if (dart.library.ffi) 'native.dart';

Never _unsupported() {
  throw UnsupportedError(
      'No suitable database implementation was found on this platform.');
}