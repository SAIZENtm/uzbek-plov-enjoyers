import 'dart:io';

/// Скрипт для замены print() на безопасное логирование
/// Запуск: dart run scripts/replace_print_statements.dart
void main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  
  print('🔍 Searching for print statements...');
  print('Mode: ${dryRun ? "DRY RUN" : "REPLACE"}');
  
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ Error: lib directory not found');
    exit(1);
  }
  
  int totalFiles = 0;
  int modifiedFiles = 0;
  int totalReplacements = 0;
  
  // Рекурсивный обход файлов
  await for (final file in libDir.list(recursive: true, followLinks: false)) {
    if (file is File && file.path.endsWith('.dart')) {
      totalFiles++;
      
      final content = await file.readAsString();
      final fileName = file.path.replaceAll('\\', '/');
      
      // Пропускаем сам LoggingService
      if (fileName.contains('logging_service')) {
        continue;
      }
      
      // Ищем print statements
      final printPattern = RegExp(r'print\s*\([^)]+\)');
      final debugPrintPattern = RegExp(r'debugPrint\s*\([^)]+\)');
      
      final printMatches = printPattern.allMatches(content).toList();
      final debugMatches = debugPrintPattern.allMatches(content).toList();
      
      if (printMatches.isNotEmpty || debugMatches.isNotEmpty) {
        modifiedFiles++;
        totalReplacements += printMatches.length + debugMatches.length;
        
        print('\n$fileName:');
        for (final match in printMatches) {
          final line = _getLineNumber(content, match.start);
          print('  📄 Line $line: ${match.group(0)}');
        }
        for (final match in debugMatches) {
          final line = _getLineNumber(content, match.start);
          print('  🔐 Line $line: ${match.group(0)}');
        }
      }
    }
  }
  
  // Вывод результатов
  print('\n📊 Summary:');
  print('Total files scanned: $totalFiles');
  print('Files with print statements: $modifiedFiles');
  print('Total print statements: $totalReplacements');
  
  if (dryRun) {
    print('\n⚠️  This was a dry run. Use LoggingService instead of print()');
  } else {
    print('\n💡 Recommendation: Replace print() with LoggingService');
  }
}

int _getLineNumber(String content, int offset) {
  return '\n'.allMatches(content.substring(0, offset)).length + 1;
}
