import 'package:crypto/crypto.dart';

String contentHash(List<int> bytes) => sha256.convert(bytes).toString();
