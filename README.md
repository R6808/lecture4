# lecture4 — Dart 语言基础三：异步、异常与包管理

移动应用软件开发实训 课堂作业四（第 6 周）独立项目仓库。

用异步方式读取本地 JSON 数据集，解析成模型类，汇总输出统计结果；
同时把"出错怎么办"当作一等公民来设计——文件缺失、字段缺失、类型错误
三类问题都给出人能看懂的提示，而不是把堆栈甩给用户。

- 姓名：容磊
- 学号：20251060108
- 仓库地址：https://github.com/R6808/lecture4
- 运行环境：Dart SDK 3.13.4（Windows）
- 对应实践指南：《学生实践指南四　Dart 语言基础三：异步、异常与包管理》
- 对应案例：`async_json`（课堂案例复现）

---

## 一、快速开始

```bash
dart pub get                     # 拉依赖
dart analyze                     # 静态检查，期望 No issues found!
dart test                        # 单元测试，期望 All tests passed!（35 个用例）
dart run bin/async_json.dart     # 正常路径：读取并汇总 data/books.json
```

观察异常路径：

```bash
# 文件缺失
dart run bin/async_json.dart data/不存在的文件.json

# 对照：改造前的嵌套回调版（功能完全相同）
dart run bin/callback_hell.dart

# 自主实践任务 2：三类异常兜底演示
dart run bin/practice_exceptions.dart

# 自主实践任务 3：JSON roundtrip 一致性验证
dart run bin/practice_roundtrip.dart
```

三个独立研究模块：

```bash
dart run research/stream_vs_future.dart      # 独立研究一：Stream 与 Future 链对比
dart run research/future_wait_parallel.dart  # 独立研究二：Future.wait 并行实验
dart run research/isolate_demo.dart          # 独立研究三：同步重计算 vs Isolate
```

---

## 二、目录结构

```
lecture4/
├── bin/
│   ├── async_json.dart          案例复现统一入口（await 版）
│   ├── callback_hell.dart       自主实践1 的"改造前"：嵌套回调版
│   ├── practice_exceptions.dart 自主实践2：三类异常兜底演示
│   └── practice_roundtrip.dart  自主实践3：JSON roundtrip 验证
├── lib/
│   ├── book.dart                Book 模型：fromJson / toJson + 可读异常
│   ├── book_repository.dart     读取与解析：把文件问题翻译成人话
│   └── book_stats.dart          统计与报告（集合链式方法）
├── data/
│   └── books.json               数据集（18 本，字段 id/title/category/borrowCount）
├── test/
│   ├── book_test.dart           模型与解析的单元测试
│   └── book_stats_test.dart     统计逻辑的单元测试
├── research/                    三个独立研究模块
├── progress.md                  进度报告四（十节全文）
└── README.md                    本文件
```

---

## 三、任务对照表

### 3.1 案例复现 `async_json`

| 指南要求 | 实现位置 | 验证方式 |
| --- | --- | --- |
| 步骤一：准备数据与依赖 | `data/books.json` + `pubspec.yaml` | `dart pub get` 成功 |
| 步骤二：解析与统计 | `lib/book.dart`、`lib/book_repository.dart`、`lib/book_stats.dart` | `dart run bin/async_json.dart` |
| 步骤三：异常路径 | `lib/book_repository.dart` 的 `DataFileException` | `dart run bin/async_json.dart data/不存在.json` |
| 检查点：正常路径统计输出正确 | 总数 18、借阅总次数 1646、Top3 | 与手算逐项核对，见 `progress.md` 第五节 |
| 检查点：文件缺失路径输出友好提示不崩溃 | 输出"数据文件缺失，请检查 …"，退出码 1 | 同上 |

### 3.2 自主实践基本要求

| 序 | 任务 | 实现位置 | 说明 |
| --- | --- | --- | --- |
| 1 | async/await 改写回调版 | `bin/callback_hell.dart`（改造前）↔ `bin/async_json.dart`（改造后） | 两者功能完全相同、输出逐字符一致。回调版是 4 层嵌套、每层都要重新接一次错误；await 版是一段直线代码，错误只需在最外层接一次 |
| 2 | 异常兜底（文件缺失、字段缺失、类型错误） | `lib/book.dart`、`lib/book_repository.dart`、`bin/practice_exceptions.dart` | 三类问题全部带位置信息；`bin/practice_exceptions.dart` 逐条演示 12 个场景 |
| 3 | JSON 解析为模型类 + roundtrip | `lib/book.dart`、`bin/practice_roundtrip.dart` | 四轮验证：文本→对象→文本、对象→文本→对象、幂等性、边界值与特殊字符 |
| 4 | pubspec 依赖规范（`^` 约束） | `pubspec.yaml`、`pubspec.lock` | 全部 `^` 约束；无冗余依赖（实测移除了 `path_provider`）；锁定文件已提交 |
| 5 | AI 使用标注 | `progress.md` 第七节 | 逐条列出用途、指令摘要、输出、本人验证方式 |

### 3.3 独立研究任务（选做）

| 序 | 任务 | 文件 | 主要结论 |
| --- | --- | --- | --- |
| 1 | Stream 与 Future 链对比 | `research/stream_vs_future.dart` | Future 是"一次性"的，链式调用会丢掉中间值；Stream 能边到边处理。实测 Stream 三个值分别在 313/619/930 ms 到达，而 Future 链只拿得到最后一个 |
| 2 | `Future.wait` 并行实验 | `research/future_wait_parallel.dart` | 三个 1 秒任务：串行 3023 ms、并行 1013 ms（提速 2.98 倍）。部分失败时默认等全部结束（608 ms 才报错），`eagerError: true` 则 407 ms 就返回，但**其余任务不会被取消** |
| 3 | isolate 重计算演示 | `research/isolate_demo.dart` | 同步计算 827 ms 期间，20 ms 的定时器**一次都没触发**（期望 41 次）；改用 `Isolate.run` 后同样 825 ms，定时器触发 40 次。4 份工作量并行提速 3.35 倍 |

---

## 四、关键设计说明

### 4.1 为什么"字段缺失"和"类型错误"的处理方式不同

- **`borrowCount` 缺失 → 默认 0**：一条借阅记录暂时没统计到次数是合理的业务情况，
  按"借过 0 次"处理，比让整份数据都读不进来更合适。
- **`borrowCount` 类型错误 → 报错**：字段存在却是 `"很多"` 这种，说明数据源出了真问题。
  悄悄当成 0 会把错误藏起来，后面统计出来的数字全是错的。
- **`id`/`title`/`category` 缺失 → 报错**：这三个是必填字段，缺了这条记录就没有意义。

判断依据是"**这个字段缺了，数据还有没有意义**"，而不是"好不好处理"。

### 4.2 为什么用 `path` 包而不是手写字符串拼接

`data/books.json` 这种路径直接写死也能跑，但那是把 Windows 的路径习惯写进了代码。
`path` 包会按运行平台选正确的分隔符（Windows 反斜杠、Linux 正斜杠），
第 11 课做网络与文件缓存时这个习惯直接受益。

### 4.3 为什么不引入 `path_provider`

指南 4.1 节提到"本课案例用到 path 与 path_provider"。我实测了一次：

```
dart pub add path_provider     # 依赖解析"成功"
dart run bin/async_json.dart   # 287 条编译错误
```

原因是 `path_provider` 是 **Flutter 插件**，它依赖 Flutter 引擎提供的 `dart:ui`
（`Offset`、`FlutterView`、`clampDouble` 等类型）。本工程是纯 Dart 控制台程序，
没有 Flutter 引擎，所以不是"运行时才报错"，而是**整个工程直接编译不过**。

按自主实践任务 4"无冗余依赖"的要求，它被移除了（连带 22 个传递依赖一起消失）。
`path_provider` 留到第 10 课做 Flutter 应用时再用。完整错误摘要见
`progress.md` 第六节。

### 4.4 异常分层

```
DataFileException   文件层面：缺失 / 读不了 / JSON 语法错 / 顶层不是数组
BookParseException  记录层面：字段缺失 / 类型不对 / 空字符串（带"第几条"）
```

分成两层是为了让调用方能区别对待：文件问题通常要提示用户"检查路径"，
记录问题则是数据本身要修。两类都实现 `Exception` 并提供 `message` getter，
`main` 里分别 catch，最后再留一个 `catch (e)` 兜底——
按指南第三章的红线，对外提供结果的程序**不允许裸抛**。

---

## 五、检查点证据

| 检查点 | 命令 | 结果 |
| --- | --- | --- |
| 静态检查 | `dart analyze` | `No issues found!` |
| 单元测试 | `dart test` | `All tests passed!`（35 个用例） |
| 正常路径 | `dart run bin/async_json.dart` | 图书总数 18 种、借阅总次数 1646 次、平均 91.44 次/种、Top3 正确 |
| 异常路径 | `dart run bin/async_json.dart data/不存在.json` | `读取失败：数据文件缺失，请检查 …`，退出码 1，无堆栈 |

截图见 `progress.md` 第八节与仓库 `images/` 目录。

---

## 六、Git 提交记录

按实践指南第五部分"每步一次提交"执行，提交信息与指南一致：

```
feat: dataset & deps ready
feat: parse & stats from books.json
feat: robust missing-field & file handling
```

之后为自主实践、独立研究、文档与截图追加提交。

---

## 七、关于数据集

`data/books.json` 是按指南 4.1 节给出的字段结构（`id`、`title`、`category`、
`borrowCount`）自建的 18 条数据。指南要求"与统一数据集零差异"——
**拿到课程统一数据集后，直接替换 `data/books.json` 即可，代码无需任何改动**
（程序只依赖字段名，不依赖具体内容）。这一点在 `progress.md` 第七节也有说明。
