import 'package:crypto/crypto.dart' show sha256, Digest;
import 'dart:async';
import 'dart:math' show pow;
import 'dart:io' show stdout;

class CompressedData {
  final List<int> _data;
  final int _length;
  final Digest _hash;

  factory CompressedData(List<int> data) {
    Iterator<int> lengthSupplier = _decodeInt(data.sublist(32)).iterator..moveNext();
    int length = lengthSupplier.current;
    lengthSupplier.moveNext();
    return new CompressedData._(
      data.sublist(lengthSupplier.current + 32),
      length,
      new Digest(data.sublist(0, 32)));
  }

  CompressedData._(this._data, this._length, this._hash);

  Future<List<int>> decompress({log: false}) async {
    return new Future(() => decompressSync(log: log));
  }

  List<int> decompressSync({log: false}) {
    List<int> data = new List.from(_data);
    if (log) {
      print('Length difference: ${_length - data.length}');
      print('Expected hash: ${_hash.toString()}');
    }
    int firstUnknown = data.length;
    while (data.length < _length) {
      data.add(0);
    }
    Digest hash = sha256.convert(data);
    int i = 0, nonces = pow(2, _length - firstUnknown).floor();
    while (hash != this._hash) {
      if (log) {
        stdout.write('\r[${100 * i / nonces}%] ${hash.toString()}');
      }
      _incrementNonce(data, firstUnknown);
      hash = sha256.convert(data);
    }
    if (log) {
      stdout.write('\n');
    }
    return data;
  }

  List<int> getBytes() {
    return new List.from(_hash.bytes)
      ..addAll(_encodeInt(_length))
      ..addAll(_data);
  }
}

CompressedData compress(List<int> data, double ratio) {
  Digest hash = sha256.convert(data);
  int truncatedLength = (data.length * (1 - ratio)).floor();
  return new CompressedData._(data.sublist(0, truncatedLength), data.length, hash);
}

List<int> _encodeInt(int n) {
  List<int> data = new List();
  while (n != 0) {
    data.add(n & 127);
    n = (n & 0xFFFFFFFF) >> 7;
  }
  data[data.length - 1] |= 128;
  return data;
}

Iterable<int> _decodeInt(List<int> data) sync* {
  int i = 0, n = 0;
  while (true) {
    int byte = data[i];
    n |= (byte & 127) << (i * 7);
    i++;
    if ((byte & 128) != 0)
      break;
  }
  yield n;
  yield i;
}

void _incrementNonce(List<int> data, int offset) {
  if (offset >= data.length) {
    throw new RangeError.index(offset, data);
  }
  data[offset] += 1;
  if (data[offset] > 255) {
    data[offset] = 0;
    _incrementNonce(data, offset + 1);
  }
}
