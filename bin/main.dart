import 'package:args/command_runner.dart';
import 'package:rscs/rscs.dart';
import 'dart:io';

class CompressCommand extends Command {
  final String name = 'c';
  final String description = 'Compresses a file.';

  CompressCommand() {
    argParser
      ..addOption('output', abbr: 'o', help: 'The output file. Defaults to the input with a ".rscs" tacked on.')
      ..addOption('ratio', abbr: 'r', defaultsTo: '32', help: 'The compression ratio. Defaults to 32 (32%).');
  }

  @override void run() {
    int ratio = int.parse(argResults['ratio'], onError: (error) => -1);
    if (ratio <= 0 || ratio > 100) {
      print('Invalid compression ratio!');
      return;
    }
    String inputFileName = argResults.rest.join(' ');
    String outputFileName = argResults['output'] ?? inputFileName + '.rscs';
    File inFile = new File(inputFileName);
    if (!inFile.existsSync()) {
      print('No such input file!');
      return;
    }
    DateTime time = new DateTime.now();
    List<int> bytes = inFile.readAsBytesSync();
    int initialBytes = bytes.length;
    CompressedData compressed = compress(bytes, ratio / 100);
    bytes = compressed.getBytes();
    File outFile = new File(outputFileName);
    outFile.writeAsBytesSync(bytes);
    Duration dur = new DateTime.now().difference(time);
    print('Wrote $initialBytes bytes as ${bytes.length} (${100 * bytes.length / initialBytes}%) in ${dur}.');
  }
}

class DecompressCommand extends Command {
  final String name = 'd';
  final String description = 'Decompresses a file.';

  DecompressCommand() {
    argParser
      ..addOption('output', abbr: 'o', help: 'The output file. Defaults to the input with ".rscs" stripped off.');
  }

  @override run() async {
    String inputFileName = argResults.rest.join(' ');
    String outputFileName = argResults['output'] ?? inputFileName.replaceAll(new RegExp('\\.rscs\$'), '');
    File inFile = new File(inputFileName);
    if (!inFile.existsSync()) {
      print('No such input file!');
      return;
    }
    DateTime time = new DateTime.now();
    List<int> bytes = inFile.readAsBytesSync();
    int initialBytes = bytes.length;
    CompressedData compressed = new CompressedData(bytes);
    bytes = await compressed.decompress(log: true);
    File outFile = new File(outputFileName);
    outFile.writeAsBytesSync(bytes);
    Duration dur = new DateTime.now().difference(time);
    print('Inflateed $initialBytes bytes to ${bytes.length} (${100 * initialBytes / bytes.length}%) in ${dur}.');
  }
}

void main(List<String> args) {
  CommandRunner runner = new CommandRunner('rscs', 'A really stupid compression scheme.')
    ..addCommand(new CompressCommand())
    ..addCommand(new DecompressCommand())
    ..run(args);
}