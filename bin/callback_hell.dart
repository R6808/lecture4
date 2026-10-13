/// callback_hell.dart — 自主实践任务 1 的"改造前"版本
///
/// 任务要求：把嵌套回调版改为顺序 await 版。
/// 本文件保留改造**之前**的写法，用来和 bin/async_json.dart 做对照。
///
/// 两者的功能完全相同——都读 data/books.json、解析成 Book、打印同一份统计报告。
/// 区别只在"控制流怎么表达"。
///
/// 运行：dart run bin/callback_hell.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:lecture4/book.dart';
import 'package:lecture4/book_stats.dart';

/// 回调风格的数据加载
///
/// 注意这个函数**不返回任何东西**，也**不抛异常**：
/// 结果和错误都要靠调用方传进来的两个回调"送出去"。
/// 这是回调风格最本质的特征，也是它所有麻烦的根源。
void loadBooksWithCallbacks({
  required String path,
  required void Function(List<Book> books) onSuccess,
  required void Function(String message) onError,
}) {
  // ── 第 1 层：先确认文件在不在 ────────────────────────────
  File(path).exists().then(
    (exists) {
      if (!exists) {
        onError('数据文件缺失，请检查 $path');
        return;
      }

      // ── 第 2 层：读文件内容 ──────────────────────────────
      File(path).readAsString().then(
        (text) {
          // ── 第 3 层：解析 JSON ───────────────────────────
          final Object? decoded;
          try {
            decoded = jsonDecode(text);
          } on FormatException catch (e) {
            onError('数据文件不是合法的 JSON：${e.message}');
            return;
          }

          if (decoded is! List) {
            onError('数据文件格式不对：$path 顶层应为数组');
            return;
          }

          final books = <Book>[];
          for (var i = 0; i < decoded.length; i++) {
            final item = decoded[i];
            if (item is! Map<String, dynamic>) {
              onError('数据格式有误：第 ${i + 1} 条记录应为 JSON 对象');
              return;
            }
            try {
              books.add(Book.fromJson(item, index: i));
            } on BookParseException catch (e) {
              onError(e.message);
              return;
            }
          }

          // ── 第 4 层：算统计并输出 ────────────────────────
          onSuccess(books);
        },
        // 每往下一层，错误都要**重新接一次**，否则异常就漏掉了
        onError: (Object e) => onError('文件读取出错：$e'),
      );
    },
    onError: (Object e) => onError('检查文件时出错：$e'),
  );
}

/// 主函数
void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : 'data/books.json';

  print('=== 回调版：同样的任务，用嵌套回调实现 ===');
  print('数据文件：$path');
  print('');

  loadBooksWithCallbacks(
    path: path,
    onSuccess: (books) {
      print(BookStats(books).report());
      print('');
      print('读取并统计完成：${books.length} 条记录');
    },
    onError: (message) {
      print('读取失败：$message');
      exitCode = 1;
    },
  );
}
