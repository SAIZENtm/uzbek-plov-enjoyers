import 'dart:io';

/// Скрипт для поиска HTTP URL в коде и предложения замены на HTTPS
/// Запуск: dart run scripts/check_http_usage.dart
void main(List<String> args) async {
  final fixMode = args.contains('--fix');
  
  print('🔍 Scanning for HTTP URLs...');
  print('Mode: ${fixMode ? "FIX" : "CHECK"}');
  
  final directories = ['lib', 'test'];
  
  final httpUsages = <String, List<HttpUsage>>{};
  int totalFiles = 0;
  int filesWithHttp = 0;
  int totalHttpUrls = 0;
  
  for (final dirPath in directories) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) continue;
    
    await for (final file in dir.list(recursive: true, followLinks: false)) {
      if (file is File && file.path.endsWith('.dart')) {
        totalFiles++;
        
        final content = await file.readAsString();
        final fileName = file.path.replaceAll('\\', '/');
        
        // Ищем HTTP URLs
        final httpPattern = RegExp(r'http://[a-zA-Z0-9\-\.]+');
        final matches = httpPattern.allMatches(content);
        
        final fileUsages = <HttpUsage>[];
        
        for (final match in matches) {
          final url = match.group(0)!;
          final domain = url.replaceFirst('http://', '').split('/')[0];
          
          final isLocalhost = domain == 'localhost' || 
                              domain == '127.0.0.1' ||
                              domain.startsWith('192.168.');
          
          fileUsages.add(HttpUsage(
            line: _getLineNumber(content, match.start),
            url: url,
            isLocalhost: isLocalhost,
          ));
        }
        
        if (fileUsages.isNotEmpty) {
          filesWithHttp++;
          totalHttpUrls += fileUsages.length;
          httpUsages[fileName] = fileUsages;
        }
      }
    }
  }
  
  // Вывод результатов
  print('\n📊 Summary:');
  print('Total files scanned: $totalFiles');
  print('Files with HTTP URLs: $filesWithHttp');
  print('Total HTTP URLs found: $totalHttpUrls');
  
  if (httpUsages.isNotEmpty) {
    print('\n⚠️  HTTP URLs found:');
    
    httpUsages.forEach((file, usages) {
      print('\n$file:');
      for (final usage in usages) {
        final icon = usage.isLocalhost ? '🏠' : '⚠️';
        print('  $icon Line ${usage.line}: ${usage.url}');
      }
    });
    
    print('\n💡 Recommendation: Replace HTTP URLs with HTTPS where possible');
  } else {
    print('\n✅ No HTTP URLs found!');
  }
}

int _getLineNumber(String content, int offset) {
  return '\n'.allMatches(content.substring(0, offset)).length + 1;
}

class HttpUsage {
  final int line;
  final String url;
  final bool isLocalhost;
  
  HttpUsage({
    required this.line,
    required this.url,
    required this.isLocalhost,
  });
}
