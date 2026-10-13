/// book_repository.dart — 数据读取与解析
///
/// 对应课堂案例 async_json 步骤二：异步读取本地 JSON，解析成模型列表。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'book.dart';

/// 默认数据文件路径（相对项目根目录）
const String defaultDataPath = 'data/books.json';

/// 从 [path] 指向的 JSON 文件读取图书列表
///
/// 全程异步：`await` 期间不占住事件循环，命令行界面不会假死。
Future<List<Book>> loadBooks({String path = defaultDataPath}) async {
  final file = File(p.joinAll(p.split(path)));
  final text = await file.readAsString();
  return parseBooks(text);
}

/// 把 JSON 文本解析成图书列表
///
/// 单独抽出来是为了让单元测试不必碰磁盘，直接喂字符串就能测。
List<Book> parseBooks(String text) {
  final decoded = jsonDecode(text) as List;
  return [
    for (final item in decoded) Book.fromJson(item as Map<String, dynamic>),
  ];
}
