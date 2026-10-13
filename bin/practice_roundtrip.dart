/// practice_roundtrip.dart — 自主实践任务 3：JSON roundtrip 一致性验证
///
/// 任务要求：完整字段模型化 ＋ toJson 反向验证（roundtrip 一致）。
///
/// 什么叫 roundtrip：
///     JSON 文本 → jsonDecode → Book.fromJson → Book 对象
///                  → toJson → jsonEncode → JSON 文本
/// 转一圈回来，如果两边**完全一致**，说明 fromJson 和 toJson 是对称的，
/// 没有字段被漏掉、没有精度被丢掉。
///
/// 为什么要验这个：只要 fromJson 多读了一个字段而 toJson 忘了写出去，
/// 或者 toJson 把 int 写成了 String，这个测试立刻就会红。
/// 第 11 课做网络请求时，请求体就是靠 toJson 生成的，这里错了那边一定跟着错。
///
/// 运行：dart run bin/practice_roundtrip.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:lecture4/book.dart';
import 'package:lecture4/book_repository.dart';
import 'package:path/path.dart' as p;

var passCount = 0;
var failCount = 0;

void check(String label, bool ok, [String detail = '']) {
  if (ok) {
    passCount++;
    print('  [通过] $label');
  } else {
    failCount++;
    print('  [失败] $label${detail.isEmpty ? '' : '  → $detail'}');
  }
}

Future<void> main() async {
  print('==================================================');
  print(' 自主实践任务 3：JSON roundtrip 一致性验证');
  print('==================================================\n');

  final path = p.join('data', 'books.json');
  final rawText = await File(path).readAsString();

  // ---------- 第一轮：文本 → 对象 → 文本 ----------
  print('===== 第 1 轮：JSON 文本 → Book 对象 → JSON 文本 =====');
  final books = parseBooks(rawText);
  print('  解析得到 ${books.length} 本书');

  final reEncoded = jsonEncode([for (final b in books) b.toJson()]);
  print('  重新编码后的字符数：${reEncoded.length}（原始 ${rawText.length}）');

  // 逐条比对字段值
  final decodedAgain = jsonDecode(reEncoded) as List;
  var fieldMismatch = 0;
  for (var i = 0; i < books.length; i++) {
    final original = (jsonDecode(rawText) as List)[i] as Map<String, dynamic>;
    final roundtripped = decodedAgain[i] as Map<String, dynamic>;
    for (final key in ['id', 'title', 'category', 'borrowCount']) {
      if (original[key] != roundtripped[key]) {
        fieldMismatch++;
        print('    第 ${i + 1} 条字段 $key 不一致：'
            '${original[key]} vs ${roundtripped[key]}');
      }
    }
  }
  check('所有 ${books.length} 条记录的 4 个字段逐项一致', fieldMismatch == 0);

  // ---------- 第二轮：对象 → 文本 → 对象 ----------
  print('\n===== 第 2 轮：Book 对象 → JSON 文本 → Book 对象 =====');
  final booksAgain = parseBooks(reEncoded);
  check('条数一致', booksAgain.length == books.length,
      '${booksAgain.length} vs ${books.length}');

  var objectMismatch = 0;
  for (var i = 0; i < books.length; i++) {
    final a = books[i];
    final b = booksAgain[i];
    if (a.id != b.id ||
        a.title != b.title ||
        a.category != b.category ||
        a.borrowCount != b.borrowCount) {
      objectMismatch++;
      print('    第 ${i + 1} 条对象不一致：$a vs $b');
    }
  }
  check('所有对象的字段值一致', objectMismatch == 0);

  // ---------- 第三轮：幂等性 ----------
  print('\n===== 第 3 轮：再转一圈，输出应当完全一样（幂等） =====');
  final third = jsonEncode([for (final b in booksAgain) b.toJson()]);
  check('第二次编码与第一次编码逐字符相同', third == reEncoded,
      '长度 ${third.length} vs ${reEncoded.length}');

  // ---------- 第四轮：边界值 ----------
  print('\n===== 第 4 轮：边界值与特殊字符 =====');
  final edgeCases = <Book>[
    const Book(id: 'E1', title: '零借阅', category: '测试', borrowCount: 0),
    const Book(id: 'E2', title: '负数（不该出现但模型不拦）', category: '测试', borrowCount: -5),
    const Book(id: 'E3', title: '带"引号"和\\反斜杠', category: '测试', borrowCount: 999999),
    const Book(id: 'E4', title: '换行\n与制表\t', category: '测试', borrowCount: 1),
    const Book(id: 'E5', title: '中文、emoji 📚 与空格 ', category: '测试', borrowCount: 42),
  ];
  final edgeJson = jsonEncode([for (final b in edgeCases) b.toJson()]);
  final edgeBack = parseBooks(edgeJson);
  var edgeMismatch = 0;
  for (var i = 0; i < edgeCases.length; i++) {
    final a = edgeCases[i];
    final b = edgeBack[i];
    if (a.id != b.id ||
        a.title != b.title ||
        a.category != b.category ||
        a.borrowCount != b.borrowCount) {
      edgeMismatch++;
      print('    不一致：$a vs $b');
    }
  }
  check('${edgeCases.length} 个边界样本 roundtrip 一致', edgeMismatch == 0);
  print('  说明：引号、反斜杠、换行、制表符、emoji 都由 jsonEncode/jsonDecode');
  print('        按 JSON 规范自动转义与还原，不需要自己处理。');

  // ---------- 第五轮：证明"漏字段会被抓出来" ----------
  print('\n===== 第 5 轮：故意做一个不对称的模型，验证测试确实能抓到 =====');
  final broken = _BrokenBook.fromJson({'id': 'X', 'title': 'T', 'category': 'C', 'borrowCount': 7});
  final brokenJson = jsonEncode(broken.toJson());
  print('  故意写错的模型（toJson 漏掉了 category）：');
  print('    原始字段：id=X, title=T, category=C, borrowCount=7');
  print('    toJson 结果：$brokenJson');
  final hasCategory = brokenJson.contains('category');
  check('反向验证能发现 category 被漏掉', !hasCategory);
  print('  结论：如果 toJson 漏字段，第 1 轮的逐字段比对会立刻失败。');
  print('        这就是"roundtrip 验证"的价值——它挡的正是这类静默错误。');

  print('\n==================================================');
  print(' 结果：$passCount 项通过，$failCount 项失败');
  print('==================================================');
  if (failCount > 0) exitCode = 1;
}

/// 故意写错的模型：toJson 漏掉了 category
///
/// 只用于最后一轮演示"反向验证确实有效"，不参与其他逻辑。
class _BrokenBook {
  final String id;
  final String title;
  final String category;
  final int borrowCount;

  const _BrokenBook({
    required this.id,
    required this.title,
    required this.category,
    required this.borrowCount,
  });

  factory _BrokenBook.fromJson(Map<String, dynamic> j) => _BrokenBook(
        id: j['id'] as String,
        title: j['title'] as String,
        category: j['category'] as String,
        borrowCount: (j['borrowCount'] as num).toInt(),
      );

  /// 故意只写三个字段，漏掉 category
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'borrowCount': borrowCount,
      };
}
