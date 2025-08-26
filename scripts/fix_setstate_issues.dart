import 'dart:io';

/// Скрипт для поиска и исправления проблем с setState после await
/// Запуск: dart scripts/fix_setstate_issues.dart [--fix]
void main(List<String> args) async {
  final shouldFix = args.contains('--fix');
  final verbose = args.contains('--verbose');
  
  print('🔍 Scanning for setState issues...');
  print('Mode: ${shouldFix ? "FIX" : "CHECK"}');
  
  final issues = <String, List<Issue>>{};
  int totalFiles = 0;
  int filesWithIssues = 0;
  int totalIssues = 0;
  
  // Сканируем lib директорию
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ lib directory not found');
    exit(1);
  }
  
  await for (final file in libDir.list(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      totalFiles++;
      
      final content = await file.readAsString();
      final fileName = file.path.replaceAll('\\', '/');
      
      // Пропускаем сгенерированные файлы
      if (fileName.contains('.g.dart') || 
          fileName.contains('.freezed.dart')) {
        continue;
      }
      
      final fileIssues = await _analyzeFile(content, fileName);
      
      if (fileIssues.isNotEmpty) {
        filesWithIssues++;
        totalIssues += fileIssues.length;
        issues[fileName] = fileIssues;
        
        if (shouldFix) {
          final fixedContent = _fixIssues(content, fileIssues);
          await file.writeAsString(fixedContent);
          print('✅ Fixed: $fileName');
        }
      }
    }
  }
  
  // Вывод результатов
  print('\n📊 Summary:');
  print('Total files scanned: $totalFiles');
  print('Files with issues: $filesWithIssues');
  print('Total issues found: $totalIssues');
  
  if (issues.isNotEmpty) {
    print('\n⚠️  Issues found:\n');
    
    // Группируем по типу
    final setStateIssues = <String, List<Issue>>{};
    final subscriptionIssues = <String, List<Issue>>{};
    final timerIssues = <String, List<Issue>>{};
    final controllerIssues = <String, List<Issue>>{};
    
    issues.forEach((file, fileIssues) {
      for (final issue in fileIssues) {
        switch (issue.type) {
          case IssueType.setStateAfterAwait:
            setStateIssues.putIfAbsent(file, () => []).add(issue);
            break;
          case IssueType.unsubscribedStream:
            subscriptionIssues.putIfAbsent(file, () => []).add(issue);
            break;
          case IssueType.uncanceledTimer:
            timerIssues.putIfAbsent(file, () => []).add(issue);
            break;
          case IssueType.undisposedController:
            controllerIssues.putIfAbsent(file, () => []).add(issue);
            break;
        }
      }
    });
    
    // setState проблемы
    if (setStateIssues.isNotEmpty) {
      print('🚨 setState after await without mounted check:');
      _printIssues(setStateIssues, verbose);
    }
    
    // Подписки
    if (subscriptionIssues.isNotEmpty) {
      print('\n📡 Unsubscribed streams:');
      _printIssues(subscriptionIssues, verbose);
    }
    
    // Таймеры
    if (timerIssues.isNotEmpty) {
      print('\n⏱️  Uncanceled timers:');
      _printIssues(timerIssues, verbose);
    }
    
    // Контроллеры
    if (controllerIssues.isNotEmpty) {
      print('\n🎮 Undisposed controllers:');
      _printIssues(controllerIssues, verbose);
    }
    
    if (!shouldFix) {
      print('\n💡 Run with --fix to automatically fix these issues');
      print('   Or use SafeStateMixin for automatic lifecycle management');
    }
  } else {
    print('\n✅ No lifecycle issues found!');
  }
}

/// Анализ файла на проблемы
Future<List<Issue>> _analyzeFile(String content, String fileName) async {
  final issues = <Issue>[];
  final lines = content.split('\n');
  
  // Паттерны для поиска проблем
  
  // 1. setState после await без mounted проверки
  final setStatePattern = RegExp(
    r'await\s+.*?;\s*(?:(?!if\s*\(\s*!?mounted).)*(setState\s*\()',
    multiLine: true,
    dotAll: true,
  );
  
  // 2. StreamSubscription без cancel
  final streamPattern = RegExp(r'(\w+)\.listen\s*\(');
  final cancelPattern = RegExp(r'(\w+)\.cancel\s*\(\s*\)');
  
  // 3. Timer без cancel
  final timerPattern = RegExp(r'Timer(?:\.periodic)?\s*\(');
  
  // 4. Controller без dispose
  final controllerPattern = RegExp(r'(\w+Controller)\s+(\w+)\s*=');
  final disposePattern = RegExp(r'(\w+)\.dispose\s*\(\s*\)');
  
  // Поиск класса State
  final stateClassPattern = RegExp(r'class\s+\w+\s+extends\s+State<');
  final hasStateClass = stateClassPattern.hasMatch(content);
  
  if (!hasStateClass) {
    return issues; // Не State класс
  }
  
  // Проверяем использование SafeStateMixin
  final usesSafeMixin = RegExp(r'with\s+.*SafeStateMixin').hasMatch(content);
  
  // 1. Проверка setState после await
  for (final match in setStatePattern.allMatches(content)) {
    final lineNumber = _getLineNumber(content, match.start);
    final line = lines[lineNumber - 1].trim();
    
    // Проверяем, есть ли mounted проверка поблизости
    final contextStart = (match.start - 200).clamp(0, content.length);
    final contextEnd = (match.end + 100).clamp(0, content.length);
    final context = content.substring(contextStart, contextEnd);
    
    if (!context.contains('mounted') && !usesSafeMixin) {
      issues.add(Issue(
        type: IssueType.setStateAfterAwait,
        line: lineNumber,
        description: 'setState after await without mounted check',
        code: line,
        fix: 'Add: if (mounted) { setState(...) }',
      ));
    }
  }
  
  // 2. Проверка StreamSubscription
  final streamVars = <String>{};
  for (final match in streamPattern.allMatches(content)) {
    final varMatch = RegExp(r'(\w+)\s*=\s*').firstMatch(
      content.substring((match.start - 50).clamp(0, content.length), match.start)
    );
    
    if (varMatch != null) {
      streamVars.add(varMatch.group(1)!);
    }
  }
  
  // Проверяем отписку
  final canceledVars = <String>{};
  for (final match in cancelPattern.allMatches(content)) {
    final varName = match.group(1);
    if (varName != null) {
      canceledVars.add(varName);
    }
  }
  
  final unsubscribed = streamVars.difference(canceledVars);
  if (unsubscribed.isNotEmpty && !usesSafeMixin) {
    for (final varName in unsubscribed) {
      issues.add(Issue(
        type: IssueType.unsubscribedStream,
        line: 0, // Сложно определить точную строку
        description: 'StreamSubscription "$varName" not canceled',
        code: '$varName.listen(...)',
        fix: 'Add to dispose(): $varName.cancel();',
      ));
    }
  }
  
  // 3. Проверка Timer
  final hasTimer = timerPattern.hasMatch(content);
  final hasTimerCancel = content.contains('timer.cancel()') || 
                         content.contains('timer?.cancel()');
  
  if (hasTimer && !hasTimerCancel && !usesSafeMixin) {
    issues.add(Issue(
      type: IssueType.uncanceledTimer,
      line: 0,
      description: 'Timer not canceled',
      code: 'Timer(...)',
      fix: 'Store timer reference and cancel in dispose()',
    ));
  }
  
  // 4. Проверка Controller
  final controllers = <String>{};
  for (final match in controllerPattern.allMatches(content)) {
    controllers.add(match.group(2)!);
  }
  
  final disposedControllers = <String>{};
  for (final match in disposePattern.allMatches(content)) {
    disposedControllers.add(match.group(1)!);
  }
  
  final undisposed = controllers.difference(disposedControllers);
  if (undisposed.isNotEmpty && !usesSafeMixin) {
    for (final controller in undisposed) {
      issues.add(Issue(
        type: IssueType.undisposedController,
        line: 0,
        description: 'Controller "$controller" not disposed',
        code: '$controller = ...Controller()',
        fix: 'Add to dispose(): $controller.dispose();',
      ));
    }
  }
  
  return issues;
}

/// Исправление проблем в коде
String _fixIssues(String content, List<Issue> issues) {
  String fixedContent = content;
  
  // Сортируем по позиции в обратном порядке чтобы не сбить индексы
  issues.sort((a, b) => b.line.compareTo(a.line));
  
  for (final issue in issues) {
    switch (issue.type) {
      case IssueType.setStateAfterAwait:
        // Заменяем setState на безопасный вариант
        fixedContent = fixedContent.replaceAllMapped(
          RegExp(r'setState\s*\('),
          (match) => 'if (mounted) setState(',
        );
        break;
        
      case IssueType.unsubscribedStream:
      case IssueType.uncanceledTimer:
      case IssueType.undisposedController:
        // Для этих проблем рекомендуем использовать SafeStateMixin
        if (!fixedContent.contains('SafeStateMixin')) {
          // Добавляем импорт
          final importIndex = fixedContent.lastIndexOf('import ');
          final importEnd = fixedContent.indexOf(';', importIndex) + 1;
          
          fixedContent = fixedContent.replaceRange(
            importEnd,
            importEnd,
            "\nimport '../core/mixins/safe_state_mixin.dart';",
          );
          
          // Добавляем mixin
          fixedContent = fixedContent.replaceFirstMapped(
            RegExp(r'(class\s+\w+State\s+extends\s+State<[^>]+>)'),
            (match) => '${match.group(1)} with SafeStateMixin',
          );
        }
        break;
    }
  }
  
  return fixedContent;
}

/// Получение номера строки
int _getLineNumber(String content, int offset) {
  return '\n'.allMatches(content.substring(0, offset)).length + 1;
}

/// Вывод проблем
void _printIssues(Map<String, List<Issue>> issues, bool verbose) {
  issues.forEach((file, fileIssues) {
    print('\n  $file:');
    
    for (final issue in fileIssues) {
      if (issue.line > 0) {
        print('    Line ${issue.line}: ${issue.description}');
      } else {
        print('    ${issue.description}');
      }
      
      if (verbose) {
        print('      Code: ${issue.code}');
        print('      Fix: ${issue.fix}');
      }
    }
  });
}

/// Класс для описания проблемы
class Issue {
  final IssueType type;
  final int line;
  final String description;
  final String code;
  final String fix;
  
  Issue({
    required this.type,
    required this.line,
    required this.description,
    required this.code,
    required this.fix,
  });
}

/// Типы проблем
enum IssueType {
  setStateAfterAwait,
  unsubscribedStream,
  uncanceledTimer,
  undisposedController,
}
