/// async_json.dart — 课堂案例复现的统一入口
///
/// 对应实践指南四第五部分：异步读取课程数据集的本地副本，
/// 解析为模型并汇总输出。
///
/// 用法：
///   dart run bin/async_json.dart                      # 读默认的 data/books.json
///   dart run bin/async_json.dart data/books.json      # 指定数据文件
library;

import 'package:lecture4/book_repository.dart';
import 'package:lecture4/book_stats.dart';

Future<void> main(List<String> args) async {
  final path = args.isNotEmpty ? args.first : defaultDataPath;

  print('=== async_json：异步读取并汇总图书借阅数据 ===');
  print('数据文件：$path');
  print('');

  final stopwatch = Stopwatch()..start();

  // await 在这里的作用：把控制权交还事件循环，等磁盘读完再继续。
  final books = await loadBooks(path: path);
  final stats = BookStats(books);

  print(stats.report());

  stopwatch.stop();
  print('');
  print('读取并统计完成：${books.length} 条记录，耗时 ${stopwatch.elapsedMilliseconds} ms');
}
