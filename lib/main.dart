import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io';
import 'dart:ui';
import 'services/file_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0078D4),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme().copyWith(
          displayLarge: GoogleFonts.interTextTheme().displayLarge?.copyWith(
            fontWeight: FontWeight.w300,
            letterSpacing: -1.5,
          ),
          displayMedium: GoogleFonts.interTextTheme().displayMedium?.copyWith(
            fontWeight: FontWeight.w300,
            letterSpacing: -0.5,
          ),
          displaySmall: GoogleFonts.interTextTheme().displaySmall?.copyWith(
            fontWeight: FontWeight.w400,
          ),
          headlineLarge: GoogleFonts.interTextTheme().headlineLarge?.copyWith(
            fontWeight: FontWeight.w400,
            letterSpacing: -0.25,
          ),
          headlineMedium: GoogleFonts.interTextTheme().headlineMedium?.copyWith(
            fontWeight: FontWeight.w400,
          ),
          headlineSmall: GoogleFonts.interTextTheme().headlineSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          titleLarge: GoogleFonts.interTextTheme().titleLarge?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.15,
          ),
          titleMedium: GoogleFonts.interTextTheme().titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          titleSmall: GoogleFonts.interTextTheme().titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
          bodyLarge: GoogleFonts.interTextTheme().bodyLarge?.copyWith(
            fontWeight: FontWeight.w400,
            letterSpacing: 0.15,
          ),
          bodyMedium: GoogleFonts.interTextTheme().bodyMedium?.copyWith(
            fontWeight: FontWeight.w400,
            letterSpacing: 0.25,
          ),
          bodySmall: GoogleFonts.interTextTheme().bodySmall?.copyWith(
            fontWeight: FontWeight.w400,
            letterSpacing: 0.4,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      home: const FileComparisonScreen(),
    );
  }
}

class FileComparisonScreen extends StatefulWidget {
  const FileComparisonScreen({super.key});

  @override
  State<FileComparisonScreen> createState() => _FileComparisonScreenState();
}

class _FileComparisonScreenState extends State<FileComparisonScreen>
    with TickerProviderStateMixin {
  String comparisonFileContent = '';
  String comparisonFileName = '';
  bool showResults = false;
  bool isLoading = false;
  String? errorMessage;
  Map<String, dynamic>? comparisonResults;
  final FileService _fileService = FileService();
  late DropzoneViewController dropzoneController;
  List<String> masterFiles = [];
  bool isDragging = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _mainTabController;
  late TabController _detailsTabController;

  // New variables for progress tracking
  String progressMessage = '';
  double? progressValue;
  List<String> logs = [];
  Map<String, dynamic>? progressDetails;
  bool showDetailedResults = false;

  // Add pagination variables
  static const int _pageSize = 100;
  final Map<int, int> _currentPages = {
    0: 0,
    1: 0,
    2: 0,
  }; // Track page for each tab

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _mainTabController = TabController(length: 2, vsync: this);
    _detailsTabController = TabController(length: 3, vsync: this);
    _loadMasterFiles();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mainTabController.dispose();
    _detailsTabController.dispose();
    super.dispose();
  }

  Future<void> _loadMasterFiles() async {
    try {
      final files = await _fileService.getMasterFiles((
        message,
        progress, {
        details,
      }) {
        if (details != null && details['files'] != null) {
          setState(() {
            masterFiles = List<String>.from(details['files']);
            _animationController.forward();
          });
        }
      });
    } catch (e) {
      setState(() => errorMessage = 'Error loading master files: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv'],
      );

      if (result != null) {
        final file = result.files.single;
        if (file.bytes != null) {
          comparisonFileContent = String.fromCharCodes(file.bytes!);
          comparisonFileName = file.name;
        } else if (file.path != null) {
          final fileContent = await File(file.path!).readAsString();
          comparisonFileContent = fileContent;
          comparisonFileName = file.name;
        }
        setState(() {});
      }
    } catch (e) {
      setState(() => errorMessage = 'Error picking file: $e');
    }
  }

  Future<void> _compareFiles() async {
    if (comparisonFileContent.isEmpty) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
      showResults = false;
      showDetailedResults = false;
      logs.clear();
      progressDetails = null;
    });

    try {
      final results = await _fileService.compareWithMasterFiles(
        comparisonFileContent,
        (message, progress, {details}) {
          setState(() {
            progressMessage = message;
            progressValue = progress;
            progressDetails = details;
            logs.add('${DateTime.now().toIso8601String()}: $message');
            if (details != null) {
              logs.add('  Details: ${details.toString()}');
            }
          });
        },
      );

      setState(() {
        comparisonResults = results;
        showResults = true;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error comparing files: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _downloadResults(String type) async {
    if (comparisonResults == null) return;

    try {
      final content = _fileService.formatResults(
        type == 'duplicates'
            ? comparisonResults!['duplicates']!
            : comparisonResults!['unique']!,
      );

      await _fileService.downloadFile(
        content,
        '${type}_results', // .csv extension will be added by FileService
      );
    } catch (e) {
      setState(() => errorMessage = 'Error downloading results: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          if (showResults && comparisonResults != null)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
              ),
              child: TabBar(
                controller: _mainTabController,
                tabs: const [
                  Tab(text: 'Summary'),
                  Tab(text: 'Detailed Results'),
                ],
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _mainTabController,
              children: [
                _buildMainContent(),
                showResults && comparisonResults != null
                    ? _buildDetailedResults()
                    : const Center(child: Text('No results to display')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modern Header with Gradient
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        Theme.of(context).colorScheme.primary.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            ShaderMask(
                              shaderCallback:
                                  (bounds) => LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds),
                              child: Text(
                                'Duplicate Checker',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Compare your file against master files to find duplicates',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.compare_arrows,
                          size: 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Main Content Grid
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column - Master Files
                    Expanded(
                      flex: 2,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.folder_outlined,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.secondary,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Master Files',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '${masterFiles.length} files available',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.copyWith(
                                                color:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    if (masterFiles.isEmpty)
                                      Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 3,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Loading master files...',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyLarge?.copyWith(
                                                color:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              childAspectRatio: 2.5,
                                              crossAxisSpacing: 16,
                                              mainAxisSpacing: 16,
                                            ),
                                        itemCount: masterFiles.length,
                                        itemBuilder: (context, index) {
                                          return _buildMetroTile(
                                            masterFiles[index],
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Right Column - Upload and Compare
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          // Upload Section with Glassmorphism
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _pickFile,
                                    borderRadius: BorderRadius.circular(24),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.all(40),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color:
                                              isDragging
                                                  ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                  : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.2),
                                              ),
                                            ),
                                            child: Icon(
                                              comparisonFileName.isEmpty
                                                  ? Icons.upload_file_outlined
                                                  : Icons.file_present,
                                              size: 64,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            comparisonFileName.isEmpty
                                                ? 'Select file to compare'
                                                : comparisonFileName,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            comparisonFileName.isEmpty
                                                ? 'Click or drag and drop your file here'
                                                : 'Click to change file',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.copyWith(
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Compare Button with Gradient
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap:
                                    comparisonFileContent.isEmpty || isLoading
                                        ? null
                                        : _compareFiles,
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isLoading)
                                        Container(
                                          width: 24,
                                          height: 24,
                                          padding: const EdgeInsets.all(2),
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.compare_arrows,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      const SizedBox(width: 12),
                                      Text(
                                        isLoading
                                            ? 'Comparing...'
                                            : 'Compare Files',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (isLoading) ...[
                  const SizedBox(height: 32),
                  _buildProgressSection(),
                ],

                if (errorMessage != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.errorContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.error_outline,
                                  color: Theme.of(context).colorScheme.error,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Error',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      errorMessage!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                if (showResults && comparisonResults != null) ...[
                  const SizedBox(height: 32),
                  _buildResultsCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetroTile(String fileName) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.insert_drive_file_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        fileName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.timeline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Processing Progress',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (progressValue != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: Colors.grey.withOpacity(0.1),
                      minHeight: 8,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (progressDetails != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildProgressDetail(
                            'Processed',
                            '${progressDetails!['processed']} / ${progressDetails!['total']}',
                            Icons.check_circle_outline,
                          ),
                        ),
                        Expanded(
                          child: _buildProgressDetail(
                            'Valid Numbers',
                            progressDetails!['valid']?.toString() ?? '0',
                            Icons.done_all,
                          ),
                        ),
                        Expanded(
                          child: _buildProgressDetail(
                            'Invalid Numbers',
                            progressDetails!['invalid']?.toString() ?? '0',
                            Icons.warning_outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.history,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Progress Log',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          logs[index],
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDetail(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedResults() {
    if (comparisonResults == null) return const SizedBox();

    final duplicates = comparisonResults!['duplicates'] as List<dynamic>;
    final unique = comparisonResults!['unique'] as List<dynamic>;
    final invalidNumbers =
        comparisonResults!['invalidNumbers'] as List<dynamic>;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.table_chart_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Detailed Analysis',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                _buildTabButton(
                  'Duplicates',
                  duplicates.length,
                  Icons.file_copy_outlined,
                  Theme.of(context).colorScheme.error,
                  0,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  'Unique',
                  unique.length,
                  Icons.check_circle_outline,
                  Theme.of(context).colorScheme.tertiary,
                  1,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  'Invalid',
                  invalidNumbers.length,
                  Icons.warning_outlined,
                  Theme.of(context).colorScheme.secondary,
                  2,
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _detailsTabController,
              children: [
                _buildDataTable(duplicates, isDuplicate: true, tabIndex: 0),
                _buildDataTable(unique, tabIndex: 1),
                _buildDataTable(invalidNumbers, isInvalid: true, tabIndex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    String label,
    int count,
    IconData icon,
    Color color,
    int index,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _detailsTabController.animateTo(index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    NumberFormat.compact().format(count),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable(
    List<dynamic> data, {
    bool isDuplicate = false,
    bool isInvalid = false,
    required int tabIndex,
  }) {
    // Get the current page for this tab
    int currentPage = _currentPages[tabIndex] ?? 0;

    // Reset current page if it's out of bounds
    if (currentPage * _pageSize >= data.length) {
      currentPage = 0;
      _currentPages[tabIndex] = 0;
    }

    final int totalPages = (data.length / _pageSize).ceil();
    final int startIndex = currentPage * _pageSize;
    final int endIndex = math.min(startIndex + _pageSize, data.length);

    // Safety check to prevent invalid indices
    if (startIndex >= data.length) {
      currentPage = 0;
      _currentPages[tabIndex] = 0;
    }

    final currentData = data.sublist(
      math.min(startIndex, data.length),
      math.min(endIndex, data.length),
    );

    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Showing ${startIndex + 1}-$endIndex of ${NumberFormat.compact().format(data.length)} Entries',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      final text = data
                          .map((item) {
                            if (item is Map) {
                              return '${item['number']},${item['state'] ?? ''},${item['source'] ?? ''}';
                            }
                            return item.toString();
                          })
                          .join('\n');
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All entries copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Copy All',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  ),
                  dataRowColor: WidgetStateProperty.resolveWith<Color?>((
                    Set<WidgetState> states,
                  ) {
                    if (states.contains(WidgetState.selected)) {
                      return Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.08);
                    }
                    return null;
                  }),
                  columns: [
                    DataColumn(
                      label: Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text('Phone Number'),
                        ],
                      ),
                    ),
                    if (isDuplicate) ...[
                      const DataColumn(label: Text('State')),
                      const DataColumn(label: Text('Source')),
                    ],
                    DataColumn(
                      label: Row(
                        children: [
                          const Text('Actions'),
                          IconButton(
                            icon: const Icon(Icons.help_outline, size: 16),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Actions Help'),
                                      content: const Text(
                                        'Click the copy icon to copy individual numbers.\n'
                                        'Use "Copy All" above to copy all numbers at once.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  rows:
                      currentData.map((item) {
                        final number =
                            item is Map ? item['number'] : item.toString();
                        return DataRow(
                          cells: [
                            DataCell(Text(number)),
                            if (isDuplicate) ...[
                              DataCell(Text(item['state'] ?? '')),
                              DataCell(Text(item['source'] ?? '')),
                            ],
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.copy,
                                      size: 20,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: number),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Number copied to clipboard',
                                          ),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPaginationButton(
                  Icons.first_page,
                  () => setState(() => _currentPages[tabIndex] = 0),
                  currentPage > 0,
                ),
                _buildPaginationButton(
                  Icons.chevron_left,
                  () =>
                      setState(() => _currentPages[tabIndex] = currentPage - 1),
                  currentPage > 0,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Page ${currentPage + 1} of $totalPages',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _buildPaginationButton(
                  Icons.chevron_right,
                  () =>
                      setState(() => _currentPages[tabIndex] = currentPage + 1),
                  currentPage < totalPages - 1,
                ),
                _buildPaginationButton(
                  Icons.last_page,
                  () =>
                      setState(() => _currentPages[tabIndex] = totalPages - 1),
                  currentPage < totalPages - 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationButton(
    IconData icon,
    VoidCallback onPressed,
    bool enabled,
  ) {
    return Material(
      color: Colors.transparent,
      child: IconButton(
        icon: Icon(icon),
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          backgroundColor:
              enabled
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
          foregroundColor:
              enabled ? Theme.of(context).colorScheme.primary : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    final totalProcessed = comparisonResults!['stats']['totalProcessed'] as int;
    final totalDuplicates =
        comparisonResults!['stats']['duplicatesFound'] as int;
    final duplicatePercentage = (totalDuplicates / totalProcessed * 100)
        .toStringAsFixed(1);
    final uniqueEntries = comparisonResults!['stats']['uniqueFound'] as int;
    final uniquePercentage = (uniqueEntries / totalProcessed * 100)
        .toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Header Section with Summary
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.analytics_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Analysis Results',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Processed ${NumberFormat.compact().format(totalProcessed)} entries',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Duplicates',
                            NumberFormat.compact().format(totalDuplicates),
                            '$duplicatePercentage%',
                            Icons.file_copy_outlined,
                            Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSummaryCard(
                            'Unique',
                            NumberFormat.compact().format(uniqueEntries),
                            '$uniquePercentage%',
                            Icons.check_circle_outline,
                            Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content Section
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Distribution Chart Section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.pie_chart_outline,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Duplicate Distribution',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ..._buildDistributionBars(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            'Download Duplicates',
                            'Export all duplicate entries',
                            Icons.file_download_outlined,
                            [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.8),
                            ],
                            () => _downloadResults('duplicates'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            'Download Unique',
                            'Export all unique entries',
                            Icons.download_done_outlined,
                            [
                              Theme.of(context).colorScheme.tertiary,
                              Theme.of(
                                context,
                              ).colorScheme.tertiary.withOpacity(0.8),
                            ],
                            () => _downloadResults('unique'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDistributionBars() {
    final duplicatesPerFile =
        comparisonResults!['stats']['duplicatesPerFile']
            as Map<String, List<dynamic>>;
    final totalDuplicates =
        comparisonResults!['stats']['duplicatesFound'] as int;
    final sortedEntries =
        duplicatesPerFile.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return sortedEntries.map((entry) {
      final percentage = (entry.value.length / totalDuplicates * 100)
          .toStringAsFixed(1);
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat.compact().format(entry.value.length)} duplicates',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$percentage%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: entry.value.length / totalDuplicates,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.7),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    String percentage,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  percentage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    List<Color> gradientColors,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
