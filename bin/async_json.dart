/// async_json.dart — 课堂案例复现的统一入口
///
/// 对应实践指南四第五部分：异步读取课程数据集的本地副本，
/// 解析为模型并汇总输出。
///
/// 用法：
///   dart run bin/async_json.dart                      # 读默认的 data/books.json
///   dart run bin/async_json.dart data/books.json      # 指定数据文件
///   dart run bin/async_json.dart data/不存在.json      # 观察文件缺失路径
library;

import 'dart:io';

import 'package:lecture4/book.dart';
import 'package:lecture4/book_repository.dart';
import 'package:lecture4/book_stats.dart';

Future<void> main(List<String> args) async {
  // 允许用命令行参数指定数据文件，方便演示"文件缺失"这条路径，
  // 不必真的去把 data/books.json 改名。
  final path = args.isNotEmpty ? args.first : defaultDataPath;

  print('=== async_json：异步读取并汇总图书借阅数据 ===');
  print('数据文件：$path');
  print('');

  final stopwatch = Stopwatch()..start();

  try {
    // await 在这里的作用：把控制权交还事件循环，等磁盘读完再继续。
    // 期间不会阻塞其他任务（详见 research/stream_vs_future.dart 的实测）。
    final books = await loadBooks(path: path);
    final stats = BookStats(books);

    print(stats.report());

    stopwatch.stop();
    print('');
    print('读取并统计完成：${books.length} 条记录，耗时 ${stopwatch.elapsedMilliseconds} ms');
  } on DataFileException catch (e) {
    // 文件层面的问题：给出人能看懂的提示，不打印堆栈
    print('读取失败：${e.message}');
    exitCode = 1;
  } on BookParseException catch (e) {
    // 数据格式层面的问题：已经带上了"第几条、哪个字段"
    print('解析失败：${e.message}');
    exitCode = 1;
  } catch (e) {
    // 兜底：按指南要求，任何对外提供结果的程序都不允许裸抛
    print('发生未知错误：$e');
    exitCode = 1;
  }
}
