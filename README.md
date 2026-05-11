# KiCad Routing Integration

将 **KiCadRouting Tools**（Rust 加速 A* 自动布线引擎）桥接到 **嘉立创EDA专业版（EasyEDA Pro）** 的完整解决方案。

## 系统架构

```
┌─────────────────────┐     HTTP (localhost:8765)     ┌──────────────────────┐
│  EasyEDA Pro 编辑器  │ ◄──────────────────────────► │   Bridge Server      │
│  (嘉立创EDA专业版)    │                              │   (Python/FastAPI)   │
│                     │                              │                      │
│  ┌───────────────┐  │                              │  ┌────────────────┐  │
│  │ TypeScript 扩展│  │  ← 收集PCB数据 / 写回结果 →   │  │ 格式转换        │  │
│  │ (kicad-routing │  │                              │  │ EasyEDA ↔ KiCad│  │
│  │  -bridge)     │  │                              │  └───────┬────────┘  │
│  └───────────────┘  │                              │          │           │
└─────────────────────┘                              │          ▼           │
                                                     │  ┌────────────────┐  │
                                                     │  │ KiCadRouting   │  │
                                                     │  │ Tools 布线引擎  │  │
                                                     │  │ (Python + Rust)│  │
                                                     │  └────────────────┘  │
                                                     └──────────────────────┘
```

## 目录结构

```
KICAD Routing-intergration/
├── KiCadRoutingTools/              # 布线引擎（Rust加速A*路由器）
│   ├── route.py                    # 单端布线 CLI
│   ├── route_diff.py               # 差分对布线 CLI
│   ├── route_planes.py             # 电源/地平面 CLI
│   ├── rust_router/                # Rust A* 实现
│   └── ...
├── kicad-routing-bridge/           # EasyEDA Pro 扩展 + 桥接服务器
│   ├── src/index.ts                # 扩展入口（TypeScript）
│   ├── iframe/                     # 扩展 UI（参数配置对话框）
│   ├── bridge_server/              # Python 桥接服务器
│   │   ├── server.py               # FastAPI 服务（端口 8765）
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

## 环境要求

| 组件 | 版本要求 |
|------|---------|
| Python | 3.7+ |
| Node.js | 20.5.0+ |
| Rust | stable（用于编译路由器） |
| EasyEDA Pro | 2.3.0+ |
| npm | 随 Node.js 安装 |

## 完整安装与操作流程

### 第一步：克隆仓库

```bash
git clone <repository-url>
cd "KICAD Routing-intergration"
```

### 第二步：编译 Rust 布线引擎

```bash
cd KiCadRoutingTools
python build_router.py
cd ..
```

> 注意：不要直接运行 `cargo build`，必须通过 `build_router.py` 构建，它会处理库文件复制和版本校验。

### 第三步：安装桥接服务器依赖

```bash
cd kicad-routing-bridge/bridge_server
pip install -r requirements.txt
cd ../..
```

依赖包括：fastapi、uvicorn、pydantic、numpy。

### 第四步：安装扩展前端依赖并编译

```bash
cd kicad-routing-bridge
npm install
npm run compile
cd ..
```

### 第五步：打包扩展（.eext 文件）

```bash
cd kicad-routing-bridge
npm run build
cd ..
```

生成文件：`kicad-routing-bridge_v1.2.0.eext`（ZIP 格式，包含 dist/、locales/、iframe/、images/、extension.json）。

### 第六步：安装扩展到 EasyEDA Pro

1. 打开 EasyEDA Pro（嘉立创EDA专业版）
2. 进入 **扩展** → **扩展管理器**
3. 选择 **从本地安装**，选中生成的 `.eext` 文件
4. 重启 EasyEDA Pro

### 第七步：启动桥接服务器

```bash
cd kicad-routing-bridge/bridge_server
python server.py
```

或者双击 `start_server.bat`（Windows，会自动检测并安装依赖）。

服务器启动后监听 `http://localhost:8765`。

### 第八步：在 EasyEDA Pro 中使用

1. 打开一个 PCB 文件
2. 顶部菜单栏点击 **KiCad 布线** → **打开布线工具...**
3. 在弹出的对话框中：
   - 选择要布线的网络
   - 配置布线参数（线宽、间距、过孔大小、层选择等）
   - 点击 **开始布线**
4. 等待布线完成，结果自动写回 PCB

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

## 布线功能

- **单端布线** — A* 寻路，支持 MPS 网络排序、拆线重布、总线检测
- **差分对布线** — 中心线 + 偏移，自动极性交换，GND 过孔放置
- **电源平面** — 自动过孔连接 SMD 焊盘到内层铜皮，Voronoi 分区
- **BGA 扇出** — 自动逃逸路径生成
- **QFN 扇出** — QFN/QFP 焊盘延伸
- **长度匹配** — DDR4 字节通道自动分组，蛇形走线
- **阻抗控制** — 根据叠层自动计算每层线宽
- **目标交换优化** — 匈牙利算法最小化交叉

## 开发命令速查

```bash
# === 扩展开发 ===
cd kicad-routing-bridge
npm run compile              # 编译 TypeScript
npm run build                # 编译 + 打包 .eext
npm run fix                  # 代码格式化 + lint

# === 桥接服务器 ===
cd kicad-routing-bridge/bridge_server
python server.py             # 启动服务器

# === 布线引擎 ===
cd KiCadRoutingTools
python build_router.py       # 编译 Rust 路由器
python route.py input.kicad_pcb                    # 单端布线
python route_diff.py input.kicad_pcb --nets "*"    # 差分对布线
python route_planes.py input.kicad_pcb --nets GND --plane-layers B.Cu  # 电源平面

# === 测试 ===
cd KiCadRoutingTools
python tests/test_fanout_and_route.py --all        # 完整集成测试
python tests/test_fanout_and_route.py --all --quick  # 快速模式

# === 验证 ===
cd KiCadRoutingTools
python check_drc.py output.kicad_pcb               # DRC 检查
python check_connected.py output.kicad_pcb         # 连通性检查
```

## 打包独立可执行文件（可选）

桥接服务器可打包为单文件 EXE，方便分发：

```bash
cd kicad-routing-bridge/bridge_server
build_exe.bat
```

生成 `dist/kicad-routing-bridge.exe`，运行即启动服务器，无需 Python 环境。

## 注意事项

- 桥接服务器同一时间只能运行一个布线任务，提交新任务会自动取消上一个
- 板框间距（board_edge_clearance）建议 ≥ 0.5mm，避免阶梯状走线
- 单位转换链路：EasyEDA UI (mm) → 扩展内部 (mil) → 服务器 (mil→mm) → 布线引擎 (mm)
- 修改 Rust 路由器后需要在 `rust_router/Cargo.toml` 中更新版本号

## 许可证

- KiCadRoutingTools: MIT License
- kicad-routing-bridge: Apache-2.0 License
