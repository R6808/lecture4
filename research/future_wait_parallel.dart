/// 独立研究二：Future.wait 并行实验
///
/// 研究问题：三个各耗时 1 秒的独立任务，串行和并行差多少？
/// 并行时若其中一个失败，其余任务会怎样？
///
/// 结论先说：
/// - 串行 `await` 三次 ≈ 3 秒；`Future.wait` ≈ 1 秒，**提速约 3 倍**。
/// - 关键前提是"任务彼此独立"。有依赖关系时必须串行。
/// - `Future.wait` 默认会**等所有任务都结束**才报出第一个错误；
///   加 `eagerError: true` 才会"一错就返回"。
///
/// 运行：dart run research/future_wait_parallel.dart
library;

import 'dart:async';

/// 一个耗时 [ms] 毫秒后返回 [value] 的异步任务
///
/// 用 Future.delayed 模拟真实耗时（网络请求、磁盘读取等）。
Future<String> task(String name, int ms, {bool shouldFail = false}) async {
  await Future<void>.delayed(Duration(milliseconds: ms));
  if (shouldFail) {
    throw StateError('$name 执行失败');
  }
  return '$name 完成';
}

/// 串行执行三个任务
Future<List<String>> serial() async {
  final results = <String>[];
  results.add(await task('任务A', 1000));
  results.add(await task('任务B', 1000));
  results.add(await task('任务C', 1000));
  return results;
}

/// 并行执行三个任务
Future<List<String>> parallel() async {
  return Future.wait([
    task('任务A', 1000),
    task('任务B', 1000),
    task('任务C', 1000),
  ]);
}

Future<void> main() async {
  print('==================================================');
  print(' 独立研究二：Future.wait 并行实验');
  print('==================================================\n');

  // ---------- 实验一：串行 vs 并行计时 ----------
  print('===== 实验一：串行 vs 并行 =====');

  var sw = Stopwatch()..start();
  final serialResult = await serial();
  sw.stop();
  final serialMs = sw.elapsedMilliseconds;
  print('  串行 await 三次：耗时 $serialMs ms');
  print('    结果：${serialResult.join("、")}');

  sw = Stopwatch()..start();
  final parallelResult = await parallel();
  sw.stop();
  final parallelMs = sw.elapsedMilliseconds;
  print('  Future.wait 并行：耗时 $parallelMs ms');
  print('    结果：${parallelResult.join("、")}');

  final speedup = serialMs / parallelMs;
  print('  提速约 ${speedup.toStringAsFixed(2)} 倍');
  print('  结论：三个任务各 1000 ms，串行要 3000 ms 左右，并行只要 1000 ms 左右。');
  print('        因为 await 只是"让出事件循环"，三个 I/O 等待是同时进行的。');

  // ---------- 实验二：并行度与耗时的关系 ----------
  print('\n===== 实验二：任务数增加时并行耗时的变化 =====');
  for (final n in [1, 3, 5]) {
    sw = Stopwatch()..start();
    await Future.wait([
      for (var i = 1; i <= n; i++) task('任务$i', 300),
    ]);
    sw.stop();
    print('  $n 个任务（各 300 ms）并行：${sw.elapsedMilliseconds} ms');
  }
  print('  结论：并行耗时几乎不随任务数增长（都接近单次 300 ms），');
  print('        任务越多，并行相对串行的优势越大。');

  // ---------- 实验三：部分失败 ----------
  print('\n===== 实验三：部分失败时会发生什么 =====');
  print('  场景：任务A(200ms 成功)、任务B(400ms 失败)、任务C(600ms 成功)');

  print('\n  --- 3.1 默认行为（eagerError: false）---');
  sw = Stopwatch()..start();
  var finished = <String>[];
  try {
    await Future.wait([
      task('任务A', 200).then((v) { finished.add('A'); return v; }),
      task('任务B', 400, shouldFail: true).then((v) { finished.add('B'); return v; }),
      task('任务C', 600).then((v) { finished.add('C'); return v; }),
    ]);
  } catch (e) {
    sw.stop();
    print('    捕获到异常：$e');
    print('    报错发生在第 ${sw.elapsedMilliseconds} ms');
    print('    此时已完成的任务：${finished.isEmpty ? "（无）" : finished.join("、")}');
    // B 在 400ms 失败，但 C 要到 600ms 才结束——再等一会儿看 C 有没有跑完
    await Future<void>.delayed(const Duration(milliseconds: 300));
    print('    再等 300 ms 后，已完成的任务：${finished.join("、")}');
  }
  print('    结论：默认会**等所有任务都结束**才把错误抛出来。');
  print('          所以报错时间接近最慢那个任务（600 ms 附近），而不是失败任务的 400 ms。');

  print('\n  --- 3.2 快速失败（eagerError: true）---');
  sw = Stopwatch()..start();
  finished = <String>[];
  try {
    await Future.wait(
      [
        task('任务A', 200).then((v) { finished.add('A'); return v; }),
        task('任务B', 400, shouldFail: true).then((v) { finished.add('B'); return v; }),
        task('任务C', 600).then((v) { finished.add('C'); return v; }),
      ],
      eagerError: true,
    );
  } catch (e) {
    sw.stop();
    print('    捕获到异常：$e');
    print('    报错发生在第 ${sw.elapsedMilliseconds} ms');
    print('    此时已完成的任务：${finished.isEmpty ? "（无）" : finished.join("、")}');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    print('    再等 300 ms 后，已完成的任务：${finished.join("、")}');
  }
  print('    结论：eagerError: true 时**一有错误立刻返回**（约 400 ms），');
  print('          但注意——其余任务并没有被取消，它们仍在后台跑完。');
  print('          Dart 的 Future 无法取消，这是它和 Stream 的一个重要差别。');

  // ---------- 实验四：常见误用 ----------
  print('\n===== 实验四：一个常见误用 =====');
  sw = Stopwatch()..start();
  // 错误写法：先建 Future 再逐个 await
  final f1 = task('X', 300);
  final f2 = task('Y', 300);
  final f3 = task('Z', 300);
  await f1;
  await f2;
  await f3;
  sw.stop();
  print('  先建三个 Future 再逐个 await：${sw.elapsedMilliseconds} ms');
  print('  结论：这样写**仍然是并行的**（≈300 ms），因为 Future 一旦创建就开始执行了，');
  print('        后面的 await 只是等它完成。真正决定串行的是"边创建边 await"。');
  print('        对比 serial()：那里是 await 完一个才创建下一个，所以才是 3000 ms。');

  print('\n==================================================');
  print(' 要点回顾');
  print('--------------------------------------------------');
  print('  1. Future.wait 只对**彼此独立**的任务有效；有依赖必须串行');
  print('  2. 默认等全部结束再报错；eagerError: true 一错即返回');
  print('  3. 无论哪种模式，其余任务都不会被取消（Future 不可取消）');
  print('  4. "先创建后 await" 就已经并行了，串行的根源是"边创建边等"');
  print('==================================================');
}
