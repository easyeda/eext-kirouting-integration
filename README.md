# KiRouting Integration

[English](README_EN.md) | 中文

将 **KiCadRouting Tools**（Rust 加速 A* 自动布线引擎）桥接到 **嘉立创EDA专业版（EasyEDA Pro）** 的完整解决方案。

## 项目地址

| 项目 | 地址 | 说明 |
|------|------|------|
| 本项目（扩展 + 桥接服务器） | https://github.com/easyeda/eext-kirouting-integration | EasyEDA Pro 扩展及 Python 桥接服务器 |
| KiCadRouting Tools（布线引擎） | https://github.com/drandyhaas/KiCadRoutingTools/tree/main#command-line-interface | Rust 加速 A* 路由器（原项目） |

## 系统架构

```
┌─────────────────────┐     HTTP (localhost:8765)     ┌──────────────────────┐
│  EasyEDA Pro 编辑器  │ ◄──────────────────────────► │   Bridge Server      │
│  (嘉立创EDA专业版)    │                              │   (Python/FastAPI)   │
│                     │                              │                      │
│  ┌───────────────┐  │                              │  ┌────────────────┐  │
│  │ TypeScript 扩展│  │  ← 收集PCB数据 / 写回结果 →   │  │ 格式转换        │  │
│  │ (kirouting-   │  │                              │  │ EasyEDA ↔ KiCad│  │
│  │  integration) │  │                              │  └───────┬────────┘  │
│  └───────────────┘  │                              │          │           │
└─────────────────────┘                              │          ▼           │
                                                     │  ┌────────────────┐  │
                                                     │  │ KiCadRouting   │  │
                                                     │  │ Tools 布线引擎  │  │
                                                     │  │ (Python + Rust)│  │
                                                     │  └────────────────┘  │
                                                     └──────────────────────┘
```

## 快速开始（用户安装）

只需两步即可使用：

### 第一步：安装扩展

在 EasyEDA Pro（嘉立创EDA专业版）的 **扩展广场** 中搜索 **KiRouting Integration** 并安装。

也可以手动安装：从 [GitHub Releases](https://github.com/easyeda/eext-kirouting-integration/releases/latest) 下载 `.eext` 文件，在 **扩展** → **扩展管理器** → **从本地安装** 中导入。

### 第二步：获取启动脚本

从本项目仓库获取桥接服务器：

```bash
git clone https://github.com/easyeda/eext-kirouting-integration.git
```

或直接在 [项目页面](https://github.com/easyeda/eext-kirouting-integration) 点击 **Code** → **Download ZIP** 下载并解压。

启动脚本位于项目目录中的 `bridge_server/start_server.bat`。

### 第三步：启动桥接服务器

双击运行 `bridge_server/start_server.bat`，脚本会自动完成以下操作：

1. 检测 Python 环境，未安装则自动通过 winget 安装
2. 检测并安装 Python 依赖（fastapi、uvicorn、pydantic、numpy）
3. 检测 KiCadRoutingTools，不存在则自动从 GitHub 克隆
4. 检测 Rust 路由器编译产物，未编译则自动构建（无 Rust 环境时降级为纯 Python 模式）
5. 启动桥接服务器（监听 `http://localhost:8765`）

> 首次运行需要联网下载依赖，后续启动会跳过已完成的步骤。

### 第四步：开始使用

1. 打开一个 PCB 文件
2. 顶部菜单栏点击 **KiRouting自动布线** → **打开布线工具...**
3. 在弹出的对话框中选择网络、配置参数、点击 **开始布线**
4. 等待布线完成，结果自动写回 PCB

> 如果服务器未启动，扩展会弹出引导对话框，提供下载链接和操作说明。

## 布线功能

- **单端布线** — A* 寻路，支持 MPS 网络排序、拆线重布、总线检测
- **差分对布线** — 中心线 + 偏移，自动极性交换，GND 过孔放置
- **电源平面** — 自动过孔连接 SMD 焊盘到内层铜皮，Voronoi 分区
- **BGA 扇出** — 自动逃逸路径生成
- **QFN 扇出** — QFN/QFP 焊盘延伸
- **长度匹配** — DDR4 字节通道自动分组，蛇形走线
- **阻抗控制** — 根据叠层自动计算每层线宽
- **目标交换优化** — 匈牙利算法最小化交叉

## 布线工作流程（数据流）

```
1. 扩展从 EasyEDA Pro 读取 PCB 数据（元件、焊盘、网络、已有走线、板框）
       ↓
2. 大型元件列表分块发送 → POST /api/extra-components
       ↓
3. 完整 PCB 数据 + 布线参数 → POST /api/route
       ↓
4. 服务器格式转换：EasyEDA JSON → .kicad_pcb（坐标系、单位、层映射）
       ↓
5. 调用 KiCadRoutingTools 执行 A* 布线
       ↓
6. 对比输入/输出 .kicad_pcb，提取新增走线和过孔
       ↓
7. 转换回 EasyEDA 坐标系
       ↓
8. 扩展轮询 GET /api/status/{job_id} 等待完成
       ↓
9. 扩展获取结果 GET /api/result/{job_id}
       ↓
10. 将新走线/过孔写入 EasyEDA Pro PCB 编辑器
```

## API 接口

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/test` | 健康检查，确认服务器运行 |
| POST | `/api/extra-components` | 分块发送大型元件列表 |
| POST | `/api/route` | 提交布线任务（异步，返回 job_id） |
| GET | `/api/status/{job_id}` | 查询任务状态 |
| GET | `/api/result/{job_id}` | 获取布线结果（走线 + 过孔） |
| POST | `/api/cancel/{job_id}` | 取消正在运行的任务 |
| GET | `/api/config/defaults` | 获取默认布线参数 |
| POST | `/api/analyze/board-summary` | 板卡概览分析 |
| POST | `/api/analyze/power-nets` | 电源网络分析 |
| POST | `/api/analyze/diff-pairs` | 差分对检测 |
| POST | `/api/analyze/bus-groups` | 总线组检测 |
| POST | `/api/analyze/net-stats` | 网络统计 |

## 开发者指南

以下内容面向需要修改源码或从源码构建的开发者。

### 目录结构

```
KICAD Routing-intergration/
├── KiCadRoutingTools/              # 布线引擎（Rust加速A*路由器）
│   ├── route.py                    # 单端布线 CLI
│   ├── route_diff.py               # 差分对布线 CLI
│   ├── route_planes.py             # 电源/地平面 CLI
│   ├── rust_router/                # Rust A* 实现
│   └── ...
├── kirouting-integration/           # EasyEDA Pro 扩展 + 桥接服务器
│   ├── src/index.ts                # 扩展入口（TypeScript）
│   ├── iframe/                     # 扩展 UI（参数配置对话框）
│   ├── bridge_server/              # Python 桥接服务器
│   │   ├── server.py               # FastAPI 服务（端口 8765）
│   │   ├── start_server.bat        # 一键启动脚本（自动安装依赖）
│   │   ├── routing_runner.py       # 布线调度（调用 KiCadRoutingTools）
│   │   ├── easyeda_to_kicad.py     # EasyEDA JSON → KiCad 格式转换
│   │   ├── kicad_diff.py           # 对比输入/输出提取新走线
│   │   ├── coord_transform.py      # 坐标系转换（mil ↔ mm）
│   │   ├── layer_mapping.py        # 层映射（EasyEDA ↔ KiCad）
│   │   ├── models.py               # Pydantic 数据模型
│   │   ├── analysis.py             # AI 分析（电源网络、差分对等）
│   │   └── requirements.txt        # Python 依赖
│   ├── extension.json              # 扩展清单
│   ├── package.json                # Node.js 项目配置
│   └── tsconfig.json               # TypeScript 配置
└── README.md                       # 本文件
```

### 环境要求

| 组件 | 版本要求 | 用途 |
|------|---------|------|
| Python | 3.8+ | 桥接服务器 |
| Node.js | 20.5.0+ | 编译扩展 |
| Rust | stable | 编译路由器（可选，无则降级为纯 Python） |
| EasyEDA Pro | 2.3.0+ | 运行扩展 |

### 开发命令

```bash
# === 扩展开发 ===
cd kirouting-integration
npm install                  # 安装前端依赖
npm run compile              # 编译 TypeScript
npm run build                # 编译 + 打包 .eext
npm run fix                  # 代码格式化 + lint

# === 桥接服务器 ===
cd kirouting-integration/bridge_server
pip install -r requirements.txt  # 安装 Python 依赖
python server.py                 # 启动服务器

# === 布线引擎 ===
cd KiCadRoutingTools
python build_router.py       # 编译 Rust 路由器（不要直接 cargo build）

# === 测试 ===
cd KiCadRoutingTools
python tests/test_fanout_and_route.py --all        # 完整集成测试
python tests/test_fanout_and_route.py --all --quick  # 快速模式

# === 验证 ===
cd KiCadRoutingTools
python check_drc.py output.kicad_pcb               # DRC 检查
python check_connected.py output.kicad_pcb         # 连通性检查
```

## 注意事项

- 桥接服务器同一时间只能运行一个布线任务，提交新任务会自动取消上一个
- 板框间距（board_edge_clearance）建议 ≥ 0.5mm，避免阶梯状走线
- 单位转换链路：EasyEDA UI (mm) → 扩展内部 (mil) → 服务器 (mil→mm) → 布线引擎 (mm)
- 修改 Rust 路由器后需要在 `rust_router/Cargo.toml` 中更新版本号

## 许可证

- KiCadRoutingTools: MIT License
- kirouting-integration: Apache-2.0 License
