/// 独立研究三：isolate 重计算演示
///
/// 研究问题：Dart 是单线程事件循环模型，一段耗时的**同步计算**会发生什么？
/// 怎么解决？
///
/// 结论先说：
/// - 同步的重计算会把**整个事件循环**堵死，期间所有定时器、I/O 回调全部排队等待，
///   表现出来就是界面卡死、命令行假死。
/// - `Isolate.run` 把计算丢到另一个 isolate 执行，主 isolate 的事件循环照常运转。
/// - Flutter 里的 `compute()` 就是 `Isolate.run` 的封装（本工程是纯 Dart，直接用后者）。
///
/// 检测方法：主 isolate 上跑一个 20 ms 的周期定时器，记录每次触发的实际间隔。
/// 如果某次间隔远大于 20 ms，说明事件循环在那段时间被堵住了。
///
/// 运行：dart run research/isolate_demo.dart
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

/// 重计算任务：一段纯 CPU 的整数运算
///
/// 故意写成同步函数——它没有 await，会一口气占满 CPU。
int heavyWork(int n) {
  var acc = 0;
  for (var i = 0; i < n; i++) {
    acc = (acc + i * 2654435761) & 0x7FFFFFFF;
  }
  return acc;
}

/// 在 [body] 执行期间，用周期定时器采样事件循环的响应情况
///
/// 返回：每次定时器实际触发的时间点（毫秒）
Future<List<int>> sampleEventLoop(Future<void> Function() body) async {
  final ticks = <int>[];
  final sw = Stopwatch()..start();
  final timer = Timer.periodic(const Duration(milliseconds: 20), (_) {
    ticks.add(sw.elapsedMilliseconds);
  });
  await body();
  timer.cancel();
  return ticks;
}

/// 计算采样结果里相邻两次触发的最大间隔
int maxGap(List<int> ticks) {
  if (ticks.length < 2) return -1;
  var maxGapMs = 0;
  for (var i = 1; i < ticks.length; i++) {
    final gap = ticks[i] - ticks[i - 1];
    if (gap > maxGapMs) maxGapMs = gap;
  }
  return maxGapMs;
}

Future<void> main() async {
  print('==================================================');
  print(' 独立研究三：同步重计算 vs Isolate');
  print('==================================================\n');

  // 先摸清本机跑这段计算要多久，后面的结论才有依据
  const smallN = 5000000;
  var sw = Stopwatch()..start();
  heavyWork(smallN);
  sw.stop();
  final smallMs = sw.elapsedMicroseconds / 1000.0; // 单位：毫秒
  final nsPerIter = smallMs * 1000000.0 / smallN; // 单位：纳秒 / 次迭代
  print('本机基准：heavyWork($smallN) 耗时 ${smallMs.toStringAsFixed(1)} ms');
  print('  折算约 ${nsPerIter.toStringAsFixed(2)} 纳秒 / 次迭代');

  // 按基准反推一个"约 1 秒"的工作量：
  //   目标毫秒数 / 每次迭代毫秒数 = 需要的迭代次数
  const targetMs = 1000.0;
  final bigN = (targetMs * smallN / smallMs).round();
  print('  为凑出约 ${targetMs.toInt()} ms 的计算量，取 n = $bigN');
  print('  采样定时器周期：20 ms\n');

  // ---------- 实验一：同步执行，堵死事件循环 ----------
  print('===== 实验一：在主 isolate 上同步执行 =====');
  var syncMs = 0;
  final syncTicks = await sampleEventLoop(() async {
    sw = Stopwatch()..start();
    final r = heavyWork(bigN);
    sw.stop();
    syncMs = sw.elapsedMilliseconds;
    print('  计算完成，结果 = $r，实际耗时 $syncMs ms');
  });
  final syncExpected = syncMs ~/ 20;
  print('  这段时间里，20 ms 的定时器本应触发约 $syncExpected 次');
  print('  实际触发：${syncTicks.length} 次');
  if (syncTicks.length < 2) {
    print('  最大间隔：无法计算——一次都没触发，因为事件循环从头到尾被占住');
  } else {
    print('  最大间隔：${maxGap(syncTicks)} ms');
  }
  print('  结论：同步计算期间事件循环被**完全堵死**，$syncMs ms 里定时器一次机会都没有。');
  print('        换成 Flutter 界面，这段时间就是用户看到的"卡死不动"。');

  // ---------- 实验二：Isolate.run 卸载计算 ----------
  print('\n===== 实验二：用 Isolate.run 把计算丢到另一个 isolate =====');
  var isoMs = 0;
  Object? isoResult;
  final isoTicks = await sampleEventLoop(() async {
    final s = Stopwatch()..start();
    isoResult = await Isolate.run(() => heavyWork(bigN));
    s.stop();
    isoMs = s.elapsedMilliseconds;
  });
  final isoExpected = isoMs ~/ 20;
  print('  计算完成，结果 = $isoResult，实际耗时 $isoMs ms');
  print('  这段时间里，20 ms 的定时器本应触发约 $isoExpected 次');
  print('  实际触发：${isoTicks.length} 次');
  print('  最大间隔：${maxGap(isoTicks)} ms');
  print('  结论：总耗时几乎一样（计算量没变），但定时器**始终在稳定触发**，');
  print('        主 isolate 全程没有被堵住。这就是把 CPU 密集任务交给 isolate 的意义。');

  // ---------- 实验三：并行的 isolate ----------
  print('\n===== 实验三：多个 isolate 真正并行 =====');
  final cores = Platform.numberOfProcessors;
  print('  本机 CPU 核心数：$cores');
  final quarter = (bigN / 4).round();

  sw = Stopwatch()..start();
  for (var i = 0; i < 4; i++) {
    heavyWork(quarter);
  }
  sw.stop();
  final serialFour = sw.elapsedMilliseconds;

  sw = Stopwatch()..start();
  await Future.wait([
    for (var i = 0; i < 4; i++) Isolate.run(() => heavyWork(quarter)),
  ]);
  sw.stop();
  final parallelFour = sw.elapsedMilliseconds;

  print('  4 份 1/4 工作量，串行执行：$serialFour ms');
  print('  4 份 1/4 工作量，Isolate 并行：$parallelFour ms');
  if (parallelFour > 0) {
    print('  提速约 ${(serialFour / parallelFour).toStringAsFixed(2)} 倍');
  }
  print('  结论：这里是**真并行**（多核同时算），和 Future.wait 的"并发"不是一回事——');
  print('        Future.wait 只是让多个 I/O 等待重叠，CPU 密集任务仍然只有一个线程在算。');

  print('\n==================================================');
  print(' 三种"同时"的区别');
  print('--------------------------------------------------');
  print('  串行 await     ：一个做完再做下一个，总耗时相加');
  print('  Future.wait    ：多个 I/O 等待重叠，**不占 CPU**，适合网络/磁盘');
  print('  Isolate.run    ：多核真并行，**适合 CPU 密集计算**');
  print('');
  print('  判断口诀：任务在等（等网络、等磁盘）→ Future.wait；');
  print('            任务在算（压缩、解析、加解密）→ Isolate');
  print('==================================================');
}
