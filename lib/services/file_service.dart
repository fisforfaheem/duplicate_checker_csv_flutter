import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

typedef ProgressCallback =
    void Function(
      String message,
      double? progress, {
      Map<String, dynamic>? details,
    });

// Data structure for isolate processing
class ProcessingData {
  final List<String> lines;
  final int startIndex;
  final int endIndex;
  final bool skipHeader;

  ProcessingData(this.lines, this.startIndex, this.endIndex, this.skipHeader);
}

// Result structure for isolate processing
class ProcessingResult {
  final Set<String> validNumbers;
  final List<String> invalidNumbers;
  final int validCount;
  final int invalidCount;

  ProcessingResult(
    this.validNumbers,
    this.invalidNumbers,
    this.validCount,
    this.invalidCount,
  );
}

class FileService {
  static const String masterFilesDirectory = 'master files';
  static const int ISOLATE_COUNT =
      16; // Increased from 8 to 16 for better parallelization
  static const int BATCH_SIZE =
      50000; // Increased from 10000 to 50000 for better throughput
  static const int PROGRESS_UPDATE_INTERVAL =
      10000; // Increased from 5000 to 10000 to reduce UI updates
  static const int BUFFER_SIZE =
      32768; // Increased from 8192 to 32768 for better I/O performance
  static const int MAX_CACHE_SIZE =
      1000000; // Maximum number of phone numbers to cache

  // Cache for master files
  static final Map<String, Set<String>> _masterFileCache = {};

  // Optimized phone number cleaning using RegExp compilation
  static final RegExp _phoneNumberRegex = RegExp(r'[^\d]');

  // List of master files for web platform
  static const List<String> webMasterFiles = [
    'master files/SuppressionTomFiles.csv',
    'master files/UNIQUEIVSUPPRESSION.csv',
    // Add any new master files here for web
  ];

  /// Cleans a phone number for comparison with optimized regex
  String _cleanPhoneNumber(String input) {
    final cleaned = input.replaceAll(_phoneNumberRegex, '').trim();
    return cleaned.length > 10
        ? cleaned.substring(cleaned.length - 10)
        : cleaned;
  }

  /// Static version of _cleanPhoneNumber for isolates with optimized regex
  static String _cleanPhoneNumberStatic(String input) {
    final cleaned = input.replaceAll(_phoneNumberRegex, '').trim();
    return cleaned.length > 10
        ? cleaned.substring(cleaned.length - 10)
        : cleaned;
  }

  /// Process chunk of data in isolate with optimized memory usage
  static Future<ProcessingResult> _processDataInIsolate(
    ProcessingData data,
  ) async {
    final validNumbers = <String>{};
    final invalidNumbers = <String>[];
    int validCount = 0;
    int invalidCount = 0;

    for (var i = data.startIndex; i < data.endIndex; i++) {
      if (i >= data.lines.length) break;
      if (data.skipHeader && i == 0) continue;

      final line = data.lines[i].trim();
      if (line.isEmpty) continue;

      final number = _cleanPhoneNumberStatic(
        line.contains(',') ? line.split(',')[0] : line,
      );

      if (number.length == 10) {
        validNumbers.add(number);
        validCount++;
      } else {
        invalidNumbers.add(line);
        invalidCount++;
      }
    }

    return ProcessingResult(
      validNumbers,
      invalidNumbers,
      validCount,
      invalidCount,
    );
  }

  /// Gets all CSV files from the master files directory
  Future<List<String>> getMasterFiles(ProgressCallback onProgress) async {
    if (kIsWeb) {
      // For web, return the predefined list of master files
      onProgress(
        'Found master files for web',
        0.1,
        details: {
          'count': webMasterFiles.length,
          'files': webMasterFiles.map((f) => path.basename(f)).toList(),
        },
      );
      return webMasterFiles;
    } else {
      final dir = Directory(masterFilesDirectory);
      if (!await dir.exists()) {
        throw Exception('Master files directory not found');
      }
      final files =
          dir
              .listSync()
              .where((entity) => entity.path.toLowerCase().endsWith('.csv'))
              .map((entity) => entity.path)
              .toList();

      if (files.isEmpty) {
        throw Exception('No CSV files found in master files directory');
      }

      onProgress(
        'Found master files',
        0.1,
        details: {
          'count': files.length,
          'files': files.map((f) => path.basename(f)).toList(),
        },
      );

      return files;
    }
  }

  /// Reads and processes the contents of a CSV file with optimized parallel processing
  Future<Set<String>> readFile(
    String filePath,
    ProgressCallback onProgress,
  ) async {
    try {
      onProgress('Starting to read ${path.basename(filePath)}...', 0.0);

      // Check cache first
      if (_masterFileCache.containsKey(filePath)) {
        onProgress('Using cached data for ${path.basename(filePath)}', 0.1);
        return _masterFileCache[filePath]!;
      }

      final validNumbers = <String>{};
      final invalidNumbers = <String>[];
      int totalLines = 0;
      int processedLines = 0;
      int validCount = 0;
      int invalidCount = 0;
      final startTime = DateTime.now();

      if (kIsWeb) {
        final response = await html.HttpRequest.request(
          filePath,
          responseType: 'text',
        );
        final lines = (response.responseText ?? '').split('\n');
        totalLines = lines.length;

        // Process in larger batches with parallel processing
        final futures = <Future<ProcessingResult>>[];
        for (var i = 0; i < lines.length; i += BATCH_SIZE) {
          final endIndex = min(i + BATCH_SIZE, lines.length);
          final batch = lines.sublist(i, endIndex);

          futures.add(
            compute(
              _processDataInIsolate,
              ProcessingData(batch, 0, batch.length, i == 0),
            ),
          );
        }

        // Wait for all batches to complete
        final results = await Future.wait(futures);

        // Merge results efficiently
        for (var result in results) {
          validNumbers.addAll(result.validNumbers);
          invalidNumbers.addAll(result.invalidNumbers);
          validCount += result.validCount;
          invalidCount += result.invalidCount;
          processedLines += result.validCount + result.invalidCount;

          if (processedLines % PROGRESS_UPDATE_INTERVAL == 0) {
            _updateProgress(
              onProgress,
              filePath,
              processedLines,
              totalLines,
              validCount,
              invalidCount,
              startTime,
            );
          }
        }
      } else {
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('File not found: $filePath');
        }

        // Count lines efficiently
        totalLines = await compute(_countFileLines, filePath);
        onProgress(
          'Found $totalLines lines in ${path.basename(filePath)}',
          0.1,
        );

        // Process file in buffered chunks with parallel processing
        final stream = file
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        List<String> batch = [];
        bool isFirstBatch = true;
        final futures = <Future<ProcessingResult>>[];

        await for (var line in stream) {
          batch.add(line);

          if (batch.length >= BATCH_SIZE) {
            futures.add(
              compute(
                _processDataInIsolate,
                ProcessingData(batch, 0, batch.length, isFirstBatch),
              ),
            );

            batch = [];
            isFirstBatch = false;
          }
        }

        // Process remaining lines
        if (batch.isNotEmpty) {
          futures.add(
            compute(
              _processDataInIsolate,
              ProcessingData(batch, 0, batch.length, isFirstBatch),
            ),
          );
        }

        // Wait for all batches to complete
        final results = await Future.wait(futures);

        // Merge results efficiently
        for (var result in results) {
          validNumbers.addAll(result.validNumbers);
          invalidNumbers.addAll(result.invalidNumbers);
          validCount += result.validCount;
          invalidCount += result.invalidCount;
          processedLines += result.validCount + result.invalidCount;

          if (processedLines % PROGRESS_UPDATE_INTERVAL == 0) {
            _updateProgress(
              onProgress,
              filePath,
              processedLines,
              totalLines,
              validCount,
              invalidCount,
              startTime,
            );
          }
        }
      }

      // Cache the results if they're within size limits
      if (validNumbers.length <= MAX_CACHE_SIZE) {
        _masterFileCache[filePath] = validNumbers;
      }

      final duration = DateTime.now().difference(startTime);
      onProgress(
        'Completed processing ${path.basename(filePath)}',
        1.0,
        details: {
          'file': path.basename(filePath),
          'processed': processedLines,
          'total': totalLines,
          'valid': validCount,
          'invalid': invalidCount,
          'percentage': '100.0',
          'memoryUsage': ProcessInfo.currentRss ~/ (1024 * 1024),
          'processingTime': duration.inSeconds,
          'averageSpeed':
              '${(processedLines / max(1, duration.inSeconds))} lines/sec',
        },
      );

      return validNumbers;
    } catch (e) {
      throw Exception('Error reading file ${path.basename(filePath)}: $e');
    }
  }

  /// Helper method to update progress with consistent format
  void _updateProgress(
    ProgressCallback onProgress,
    String filePath,
    int processedLines,
    int totalLines,
    int validCount,
    int invalidCount,
    DateTime startTime,
  ) {
    final duration = DateTime.now().difference(startTime);
    final linesPerSecond = processedLines / max(1, duration.inSeconds);

    onProgress(
      'Processing ${path.basename(filePath)}',
      processedLines / totalLines,
      details: {
        'file': path.basename(filePath),
        'processed': processedLines,
        'total': totalLines,
        'valid': validCount,
        'invalid': invalidCount,
        'percentage': ((processedLines / totalLines) * 100).toStringAsFixed(1),
        'memoryUsage': ProcessInfo.currentRss ~/ (1024 * 1024),
        'processingSpeed': '${linesPerSecond.toStringAsFixed(1)} lines/sec',
        'estimatedTimeRemaining': _formatDuration(
          Duration(
            seconds:
                ((totalLines - processedLines) / max(1, linesPerSecond))
                    .round(),
          ),
        ),
      },
    );
  }

  /// Format duration in a human-readable format
  static String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Counts lines in a file efficiently using buffered reading
  static Future<int> _countFileLines(String filePath) async {
    final file = File(filePath);
    final stream = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    int count = 0;
    await for (var _ in stream) {
      count++;
    }
    return count;
  }

  /// Compares files in parallel using optimized isolate processing
  Future<Map<String, dynamic>> compareWithMasterFiles(
    String comparisonFileContent,
    ProgressCallback onProgress,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      onProgress(
        'Finding master files...',
        0.0,
        details: {'startTime': DateTime.now().toIso8601String()},
      );

      final masterFiles = await getMasterFiles(onProgress);
      if (masterFiles.isEmpty) {
        throw Exception('No master files found in $masterFilesDirectory');
      }
      onProgress('Found ${masterFiles.length} master files', 0.1);

      // Read master files in parallel with optimized processing
      final allMasterSets = <String, Set<String>>{};
      final masterFileFutures = <Future<void>>[];

      for (var filePath in masterFiles) {
        masterFileFutures.add(
          (() async {
            final fileName = path.basename(filePath);
            final numbers = await readFile(filePath, onProgress);
            if (numbers.isNotEmpty) {
              allMasterSets[fileName] = numbers;
            }
          })(),
        );
      }

      await Future.wait(masterFileFutures);

      if (allMasterSets.isEmpty) {
        throw Exception('No valid numbers found in any master file');
      }

      onProgress(
        'Master files loaded successfully',
        0.6,
        details: {
          'fileCount': allMasterSets.length,
          'totalNumbers': allMasterSets.values.fold<int>(
            0,
            (sum, set) => sum + set.length,
          ),
          'files': allMasterSets.keys.toList(),
          'loadTime': stopwatch.elapsed.inSeconds,
          'memoryUsage': ProcessInfo.currentRss ~/ (1024 * 1024),
        },
      );

      // Process comparison file in optimized batches
      final comparisonLines = comparisonFileContent.split('\n');
      final totalLines = comparisonLines.length;
      final results = {
        'duplicates': <Map<String, String>>[],
        'unique': <String>[],
        'invalidNumbers': <String>[],
        'duplicatesPerFile': <String, List<String>>{
          for (var file in allMasterSets.keys) file: [],
        },
        'multipleMatches': <String, List<String>>{},
      };

      // Process in parallel batches with optimized memory usage
      final futures = <Future<Map<String, dynamic>>>[];
      for (var i = 0; i < totalLines; i += BATCH_SIZE) {
        final endIndex = min(i + BATCH_SIZE, totalLines);
        final batch = comparisonLines.sublist(i, endIndex);

        futures.add(
          compute(
            (Map<String, dynamic> data) {
              final lines = data['lines'] as List<String>;
              final masterSets = Map<String, Set<String>>.from(
                data['masterSets'] as Map,
              );
              final skipHeader = data['skipHeader'] as bool;

              final Map<String, dynamic> batchResults = {
                'duplicates': <Map<String, String>>[],
                'unique': <String>[],
                'invalidNumbers': <String>[],
                'duplicatesPerFile': <String, List<String>>{
                  for (var file in masterSets.keys) file: [],
                },
                'multipleMatches': <String, List<String>>{},
              };

              for (var j = 0; j < lines.length; j++) {
                if (skipHeader && j == 0) continue;

                final line = lines[j].trim();
                if (line.isEmpty) continue;

                final parts = line.split(',');
                final rawNumber = parts[0];
                final state = parts.length > 1 ? parts[1].trim() : '';
                final number = _cleanPhoneNumberStatic(rawNumber);

                if (number.length != 10) {
                  (batchResults['invalidNumbers'] as List<String>).add(
                    rawNumber,
                  );
                  continue;
                }

                bool isDuplicate = false;
                List<String> foundInFiles = [];

                // Optimize duplicate checking by using Set.contains
                for (var entry in masterSets.entries) {
                  if (entry.value.contains(number)) {
                    isDuplicate = true;
                    foundInFiles.add(entry.key);
                    (batchResults['duplicatesPerFile']
                            as Map<String, List<String>>)[entry.key]!
                        .add(number);
                  }
                }

                if (isDuplicate) {
                  for (var sourceFile in foundInFiles) {
                    (batchResults['duplicates'] as List<Map<String, String>>)
                        .add({
                          'number': number,
                          'state': state,
                          'source': sourceFile,
                        });
                  }

                  if (foundInFiles.length > 1) {
                    (batchResults['multipleMatches']
                            as Map<String, List<String>>)[number] =
                        foundInFiles;
                  }
                } else {
                  (batchResults['unique'] as List<String>).add(number);
                }
              }

              return batchResults;
            },
            {'lines': batch, 'masterSets': allMasterSets, 'skipHeader': i == 0},
          ),
        );
      }

      // Wait for all batches to complete and merge results efficiently
      final batchResults = await Future.wait(futures);
      for (var batchResult in batchResults) {
        (results['duplicates'] as List<Map<String, String>>).addAll(
          batchResult['duplicates'],
        );
        (results['unique'] as List<String>).addAll(batchResult['unique']);
        (results['invalidNumbers'] as List<String>).addAll(
          batchResult['invalidNumbers'],
        );

        for (var entry
            in (batchResult['duplicatesPerFile'] as Map<String, List<String>>)
                .entries) {
          (results['duplicatesPerFile'] as Map<String, List<String>>)[entry
                  .key]!
              .addAll(entry.value);
        }

        (results['multipleMatches'] as Map<String, List<String>>).addAll(
          batchResult['multipleMatches'],
        );
      }

      stopwatch.stop();
      final stats = {
        'totalProcessed': totalLines - 1,
        'duplicatesFound': (results['duplicates'] as List).length,
        'uniqueFound': (results['unique'] as List).length,
        'invalidNumbers': (results['invalidNumbers'] as List).length,
        'duplicatesPerFile': results['duplicatesPerFile'],
        'masterFiles': allMasterSets.map(
          (key, value) => MapEntry(key, value.length),
        ),
        'multipleMatches': results['multipleMatches'],
        'performance': {
          'totalTimeSeconds': stopwatch.elapsed.inSeconds,
          'linesPerSecond': (totalLines / max(1, stopwatch.elapsed.inSeconds)),
          'peakMemoryUsageMB': ProcessInfo.currentRss ~/ (1024 * 1024),
          'isolatesUsed': ISOLATE_COUNT,
          'completedAt': DateTime.now().toIso8601String(),
        },
      };

      results['stats'] = stats;
      onProgress('Analysis complete!', 1.0, details: stats);
      return results;
    } catch (e) {
      stopwatch.stop();
      throw Exception('Error comparing files: $e');
    }
  }

  /// Downloads a file with the given content in Excel-friendly CSV format
  Future<void> downloadFile(String content, String fileName) async {
    if (!fileName.toLowerCase().endsWith('.csv')) {
      fileName = '$fileName.csv';
    }

    // Add BOM for Excel UTF-8 compatibility
    final bom = [0xEF, 0xBB, 0xBF];
    final headerRow = 'Phone Number,State,Source\n';
    final contentWithHeader = String.fromCharCodes(bom) + headerRow + content;

    if (kIsWeb) {
      final bytes = contentWithHeader.codeUnits;
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor =
          html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        throw Exception('Could not access downloads directory');
      }
      final file = File(path.join(directory.path, fileName));
      await file.writeAsBytes(bom + contentWithHeader.codeUnits);
    }
  }

  /// Formats the results for download as Excel-friendly CSV
  String formatResults(List<dynamic> entries) {
    return entries
        .map((entry) {
          if (entry is Map<String, String>) {
            return '${entry['number']},${entry['state']},${entry['source']}';
          }
          return '$entry,,';
        })
        .join('\n');
  }
}
