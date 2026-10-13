/// book_repository.dart — 数据读取与解析
///
/// 对应实践指南四第三章（异常处理）与课堂案例 async_json 步骤二、三。
///
/// 职责：把"磁盘上的一个 JSON 文件"变成"内存里的 `List<Book>`"。
/// 所有可能出错的地方（文件不存在、读不动、JSON 语法错、单条记录格式错）
/// 都在这里被翻译成人能看懂的异常，不向上层漏出裸的 FileSystemException。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'book.dart';

/// 数据文件的问题类型
enum DataFileProblem {
  /// 文件不存在
  missing,

  /// 文件存在但读不了（权限、被占用等）
  unreadable,

  /// 文件内容不是合法 JSON
  malformedJson,

  /// JSON 合法但顶层不是数组
  notAList,
}

/// 数据文件层面的异常
class DataFileException implements Exception {
  final String path;
  final DataFileProblem problem;
  final String? detail;

  const DataFileException({
    required this.path,
    required this.problem,
    this.detail,
  });

  /// 面向用户的提示文本
  String get message => switch (problem) {
        DataFileProblem.missing => '数据文件缺失，请检查 $path',
        DataFileProblem.unreadable => '数据文件无法读取：$path${detail == null ? '' : '（$detail）'}',
        DataFileProblem.malformedJson => '数据文件不是合法的 JSON：$path${detail == null ? '' : '（$detail）'}',
        DataFileProblem.notAList => '数据文件格式不对：$path 顶层应为数组',
      };

  @override
  String toString() => message;
}

/// 默认数据文件路径（相对项目根目录）
const String defaultDataPath = 'data/books.json';

/// 从 [path] 指向的 JSON 文件读取图书列表
///
/// 全程异步：`await` 期间不占住事件循环，命令行界面不会假死。
Future<List<Book>> loadBooks({String path = defaultDataPath}) async {
  final file = File(p.joinAll(p.split(path)));

  // 先判断存在性：直接读到一半再报错，用户看到的堆栈会更难懂
  if (!await file.exists()) {
    throw DataFileException(path: path, problem: DataFileProblem.missing);
  }

  final String text;
  try {
    text = await file.readAsString();
  } on FileSystemException catch (e) {
    throw DataFileException(
      path: path,
      problem: DataFileProblem.unreadable,
      detail: e.osError?.message ?? e.message,
    );
  }

  return parseBooks(text);
}

/// 把 JSON 文本解析成图书列表
///
/// 单独抽出来是为了让单元测试不必碰磁盘，直接喂字符串就能测。
List<Book> parseBooks(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw DataFileException(
      path: defaultDataPath,
      problem: DataFileProblem.malformedJson,
      detail: e.message,
    );
  }

  if (decoded is! List) {
    throw DataFileException(path: defaultDataPath, problem: DataFileProblem.notAList);
  }

  return [
    for (var i = 0; i < decoded.length; i++)
      Book.fromJson(_asMap(decoded[i], i), index: i),
  ];
}

/// 把数组里的第 [index] 项确认成 Map，不是就抛出可读异常
Map<String, dynamic> _asMap(Object? item, int index) {
  if (item is Map<String, dynamic>) return item;
  throw BookParseException(
    index: index,
    field: '(整条记录)',
    detail: '应为 JSON 对象，实际拿到 ${item.runtimeType}',
  );
}
