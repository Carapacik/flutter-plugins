import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mixin_markdown_widget/src/parser/markdown_document_parser.dart';
import 'package:mixin_markdown_widget/src/widgets/markdown_controller.dart';

void main() {
  test('incremental append benchmark', () {
    const scenarios = <_BenchmarkScenario>[
      _BenchmarkScenario(
        name: 'baseline',
        iterations: 400,
        initialBlockRepeats: 120,
      ),
      _BenchmarkScenario(
        name: 'large-prefix',
        iterations: 200,
        initialBlockRepeats: 600,
      ),
    ];

    stdout.writeln('mixin_markdown_widget incremental append benchmark');
    for (final scenario in scenarios) {
      final initialSource = _buildInitialMarkdown(
        repetitions: scenario.initialBlockRepeats,
      );
      final chunks = List<String>.generate(
        scenario.iterations,
        (index) =>
            '\n\n## Chunk $index\n\nParagraph ${index + 1} with **bold** and `code`.',
        growable: false,
      );

      _warmUp(initialSource, chunks.take(24).toList(growable: false));

      final fullResult = _benchmarkFullParse(initialSource, chunks);
      final incrementalResult = _benchmarkIncrementalParse(
        initialSource,
        chunks,
      );

      stdout.writeln('scenario: ${scenario.name}');
      stdout.writeln('iterations: ${scenario.iterations}');
      stdout.writeln('initial blocks: ${scenario.initialBlockRepeats}');
      stdout.writeln(
        'full parse elapsed: ${fullResult.elapsed.inMilliseconds} ms',
      );
      stdout.writeln('full parser timing: ${fullResult.timing.describe()}');
      stdout.writeln(
        'incremental parse elapsed: '
        '${incrementalResult.elapsed.inMilliseconds} ms',
      );
      stdout.writeln(
        'incremental parser timing: ${incrementalResult.timing.describe()}',
      );
      if (incrementalResult.elapsed.inMicroseconds > 0) {
        final speedup = fullResult.elapsed.inMicroseconds /
            incrementalResult.elapsed.inMicroseconds;
        stdout.writeln('speedup: ${speedup.toStringAsFixed(2)}x');
      }
    }
  });
}

void _warmUp(
  String initialSource,
  List<String> chunks,
) {
  _benchmarkFullParse(initialSource, chunks);
  _benchmarkIncrementalParse(initialSource, chunks);
}

_BenchmarkResult _benchmarkFullParse(
  String initialSource,
  List<String> chunks,
) {
  final timing = _TimingSummary();
  final parser = MarkdownDocumentParser(onTiming: timing.add);
  final controller = MarkdownController(data: initialSource, parser: parser);
  timing.reset();
  var source = initialSource;
  final stopwatch = Stopwatch()..start();
  for (final chunk in chunks) {
    source += chunk;
    controller.setData(source);
  }
  stopwatch.stop();
  controller.dispose();
  return _BenchmarkResult(elapsed: stopwatch.elapsed, timing: timing);
}

_BenchmarkResult _benchmarkIncrementalParse(
  String initialSource,
  List<String> chunks,
) {
  final timing = _TimingSummary();
  final parser = MarkdownDocumentParser(onTiming: timing.add);
  final controller = MarkdownController(data: initialSource, parser: parser);
  timing.reset();
  final stopwatch = Stopwatch()..start();
  for (final chunk in chunks) {
    controller.appendChunk(chunk);
  }
  stopwatch.stop();
  controller.dispose();
  return _BenchmarkResult(elapsed: stopwatch.elapsed, timing: timing);
}

String _buildInitialMarkdown({required int repetitions}) {
  final buffer = StringBuffer('# Benchmark\n');
  for (var index = 0; index < repetitions; index++) {
    buffer
      ..write('\n\nParagraph $index with a [link](https://example.com/$index).')
      ..write('\n\n- First item\n- Second item')
      ..write('\n\n```dart\nprint($index);\n```');
  }
  return buffer.toString();
}

class _BenchmarkScenario {
  const _BenchmarkScenario({
    required this.name,
    required this.iterations,
    required this.initialBlockRepeats,
  });

  final String name;
  final int iterations;
  final int initialBlockRepeats;
}

class _BenchmarkResult {
  const _BenchmarkResult({
    required this.elapsed,
    required this.timing,
  });

  final Duration elapsed;
  final _TimingSummary timing;
}

class _TimingSummary {
  int count = 0;
  int totalMicros = 0;
  int markdownParseLinesMicros = 0;
  int buildBlocksMicros = 0;
  int scanRangesMicros = 0;
  int applyRangesMicros = 0;
  int normalizeInlineMicros = 0;
  int nextIdMicros = 0;
  int totalParseLineCount = 0;
  int maxParseLineCount = 0;

  void reset() {
    count = 0;
    totalMicros = 0;
    markdownParseLinesMicros = 0;
    buildBlocksMicros = 0;
    scanRangesMicros = 0;
    applyRangesMicros = 0;
    normalizeInlineMicros = 0;
    nextIdMicros = 0;
    totalParseLineCount = 0;
    maxParseLineCount = 0;
  }

  void add(MarkdownParserTiming timing) {
    count += 1;
    totalMicros += timing.totalMicros;
    markdownParseLinesMicros += timing.markdownParseLinesMicros;
    buildBlocksMicros += timing.buildBlocksMicros;
    scanRangesMicros += timing.scanRangesMicros;
    applyRangesMicros += timing.applyRangesMicros;
    normalizeInlineMicros += timing.normalizeInlineMicros;
    nextIdMicros += timing.nextIdMicros;
    totalParseLineCount += timing.parseLineCount;
    if (timing.parseLineCount > maxParseLineCount) {
      maxParseLineCount = timing.parseLineCount;
    }
  }

  String describe() {
    if (totalMicros == 0) {
      return 'no parser samples';
    }
    String part(String name, int micros) {
      final percent = micros * 100 / totalMicros;
      final millis = micros / 1000;
      return '$name=${millis.toStringAsFixed(1)}ms '
          '(${percent.toStringAsFixed(1)}%)';
    }

    return [
      'samples=$count',
      'avgLines=${(totalParseLineCount / count).toStringAsFixed(1)}',
      'maxLines=$maxParseLineCount',
      part('markdown', markdownParseLinesMicros),
      part('build', buildBlocksMicros),
      part('scanRanges', scanRangesMicros),
      part('applyRanges', applyRangesMicros),
      part('normalizeInline', normalizeInlineMicros),
      part('nextId', nextIdMicros),
      'parserTotal=${(totalMicros / 1000).toStringAsFixed(1)}ms',
    ].join(', ');
  }
}
