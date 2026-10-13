/// practice_exceptions.dart — 自主实践任务 2：三类异常兜底
///
/// 任务要求：文件缺失、字段缺失、类型错误三类异常全部有可读提示。
///
/// 指南第三章的"红线"：任何对外提供结果的程序不允许裸抛，
/// 网络/文件路径必须捕获并给出用户可读的提示。
///
/// 本文件逐条演示这三类问题**改造前后**的差别：
/// 左边是"不管它会发生什么"，右边是本工程实际给出的提示。
///
/// 运行：dart run bin/practice_exceptions.dart
library;

import 'dart:convert';

import 'package:lecture4/book.dart';
import 'package:lecture4/book_repository.dart';

/// 跑一个场景并打印结果
void scenario(String title, String rawJson) {
  print('─' * 60);
  print('场景：$title');
  print('  原始 JSON：$rawJson');
  try {
    final books = parseBooks(rawJson);
    print('  结果：解析成功，共 ${books.length} 条');
    for (final b in books) {
      print('    $b');
    }
  } on DataFileException catch (e) {
    print('  友好提示 → ${e.message}');
  } on BookParseException catch (e) {
    print('  友好提示 → ${e.message}');
  } catch (e) {
    // 兜底：保证任何情况下都不会把裸异常抛给用户
    print('  兜底捕获 → ${e.runtimeType}: $e');
  }
  print('');
}

Future<void> main() async {
  print('==================================================');
  print(' 自主实践任务 2：三类异常兜底演示');
  print('==================================================\n');

  // ============================================================
  // 第一类：文件缺失
  // ============================================================
  print('【第一类】文件缺失\n');
  print('说明：真实读取一个不存在的文件。');
  try {
    await loadBooks(path: 'data/这个文件不存在.json');
    print('  意外：居然读成功了');
  } on DataFileException catch (e) {
    print('  友好提示 → ${e.message}');
    print('  异常类型 → ${e.runtimeType}');
    print('  问题分类 → ${e.problem}');
  }
  print('');
  print('对比：如果直接 File(...).readAsString() 不捕获，用户会看到：');
  print('  Unhandled exception:');
  print('  PathNotFoundException: Cannot open file, path = ... (OS Error: ...)');
  print('  #0      _File.throwIfError (dart:io/file_impl.dart)');
  print('  …（一长串调用栈，看不出该怎么办）');
  print('');

  // ============================================================
  // 第二类：字段缺失
  // ============================================================
  print('【第二类】字段缺失\n');

  scenario(
    '缺少必填字段 title',
    '[{"id":"B001","category":"计算机","borrowCount":10}]',
  );

  scenario(
    '缺少必填字段 id',
    '[{"title":"活着","category":"文学","borrowCount":178}]',
  );

  scenario(
    '必填字段是空字符串',
    '[{"id":"B001","title":"   ","category":"计算机","borrowCount":10}]',
  );

  print('─' * 60);
  print('特例：borrowCount 缺失**不算错误**，按 0 次借阅处理');
  scenario(
    '缺少 borrowCount（可选项，有默认值）',
    '[{"id":"B001","title":"活着","category":"文学"}]',
  );
  print('  为什么这个不报错：一条借阅记录暂时没统计到次数是合理的业务情况，');
  print('  按"借过 0 次"处理，比让整份数据都读不进来更合适。');
  print('  这条规则正是指南里"故意实验"要求的：删掉 borrowCount 字段后加默认值处理。');
  print('');

  // ============================================================
  // 第三类：类型错误
  // ============================================================
  print('【第三类】类型错误\n');

  scenario(
    'borrowCount 写成了字符串 "很多"',
    '[{"id":"B001","title":"活着","category":"文学","borrowCount":"很多"}]',
  );

  scenario(
    'id 写成了数字 1001',
    '[{"id":1001,"title":"活着","category":"文学","borrowCount":10}]',
  );

  scenario(
    '数组里混进了一个字符串',
    '[{"id":"B001","title":"活着","category":"文学","borrowCount":10}, "我不是对象"]',
  );

  scenario(
    'JSON 语法本身有问题（少了一个大括号）',
    '[{"id":"B001","title":"活着"',
  );

  scenario(
    '顶层不是数组，而是一个对象',
    '{"id":"B001","title":"活着"}',
  );

  // ============================================================
  // 第四类：类型安全的正当写法
  // ============================================================
  print('【补充】JSON 数字可能是 int 也可能是 double');
  final withInt = Book.fromJson(jsonDecode('{"id":"A","title":"T","category":"C","borrowCount":12}'));
  final withDouble = Book.fromJson(jsonDecode('{"id":"A","title":"T","category":"C","borrowCount":12.0}'));
  final withFloat = Book.fromJson(jsonDecode('{"id":"A","title":"T","category":"C","borrowCount":12.9}'));
  print('  borrowCount: 12    → ${withInt.borrowCount}（${withInt.borrowCount.runtimeType}）');
  print('  borrowCount: 12.0  → ${withDouble.borrowCount}（${withDouble.borrowCount.runtimeType}）');
  print('  borrowCount: 12.9  → ${withFloat.borrowCount}（${withFloat.borrowCount.runtimeType}）');
  print('  结论：先 `as num` 接住再 toInt()，整数和小数两条路都走得通，不会抛类型错误。');
  print('        这正是指南 4.2 节"翻车警告"强调的写法。');
  print('');

  print('==================================================');
  print(' 小结');
  print('--------------------------------------------------');
  print('  文件缺失 → DataFileException，提示"数据文件缺失，请检查 <路径>"');
  print('  字段缺失 → BookParseException，提示"第 N 条记录的 X 字段缺失"');
  print('  类型错误 → BookParseException，提示"应为字符串，实际拿到 int"');
  print('  三类问题都带位置信息，用户拿着提示就能直接去改数据。');
  print('==================================================');
}
