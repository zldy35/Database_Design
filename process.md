# 基于 MySQL 的广州高中教务系统的数据库设计

## 代码仓库目录结构

```plaintext
Database_Design/  # 仓库根目录
├── docs/                      # 文档目录：存储所有设计、说明类文档
│   ├── requirement_analysis/  # 需求分析相关文档
│   │   ├── db_requirement_analysis.md  # 数据库需求分析报告（即之前输出的内容）
│   │   ├── business_rules.md           # 业务规则约束（选科、权限、赋分等）
│   │   └── role_permission_matrix.md   # 角色-权限矩阵表（可视化权限分配）
│   ├── design/                # 数据库设计文档
│   │   ├── er_diagram/                # ER图（建议用drawio/mermaid格式）
│   │   │   ├── db_er_diagram.drawio   # 数据库ER图源文件
│   │   │   └── db_er_diagram.png      # ER图导出图片（方便查看）
│   │   ├── table_design.md            # 表结构设计详情（字段、约束、备注）
│   │   ├── index_design.md            # 索引设计（优化查询性能）
│   │   └── sql_convention.md          # SQL编写规范（命名、注释等）
│   └── deployment/            # 部署相关文档
│       ├── environment_requirements.md  # 环境要求（MySQL版本、配置等）
│       └── deployment_guide.md          # 数据库部署/迁移指南
├── sql/                       # SQL脚本目录：存储可执行的数据库脚本
│   ├── ddl/                   # DDL（数据定义语言）：建表、建索引、删表等
│   │   ├── 01_create_database.sql      # 创建数据库
│   │   ├── 02_create_tables.sql        # 创建所有表（核心脚本）
│   │   ├── 03_create_indexes.sql       # 创建索引（优化查询）
│   │   └── 04_alter_tables.sql         # 表结构变更脚本（后续迭代用）
│   ├── dml/                   # DML（数据操作语言）：初始化数据、测试数据等
│   │   ├── 01_init_base_data.sql       # 初始化基础数据（课程、角色、开班阈值等）
│   │   ├── 02_test_data.sql            # 测试数据（学生、教职工、考试成绩等）
│   │   └── 03_data_migration.sql       # 数据迁移脚本（如需从旧系统迁移）
│   ├── dcl/                   # DCL（数据控制语言）：权限分配
│   │   └── 01_grant_permissions.sql    # 给不同数据库用户分配权限（对应业务角色）
│   ├── procedures/            # 存储过程/函数：业务逻辑封装
│   │   ├── 01_score_convert_func.sql   # 政史地生赋分计算函数
│   │   ├── 02_check_class_num_proc.sql # 选科班人数阈值校验存储过程
│   │   └── 03_stat_course_choose_proc.sql # 选课人数统计存储过程
│   └── scripts/               # 辅助脚本：批量操作、定时任务等
│       ├── backup_db.sh                # 数据库备份脚本（Shell）
│       └── sync_score_data.sql         # 成绩数据同步脚本
├── src/                       # 源码目录（如需对接应用程序）
│   ├── java/                  # 若用Java对接，存储DAO/实体类（可选）
│   │   ├── entity/                     # 数据库实体类（对应表结构）
│   │   └── mapper/                     # MyBatis映射文件/接口
│   └── python/                # 若用Python对接，存储操作脚本（可选）
│       ├── db_operation.py             # 数据库增删改查封装
│       └── report_generation.py        # 报表生成（选课统计、成绩统计）
├── test/                      # 测试目录：验证数据库脚本/逻辑
│   ├── sql_test/              # SQL脚本测试用例
│   │   ├── test_score_convert.sql      # 赋分计算逻辑测试
│   │   └── test_class_choose.sql       # 选科分班逻辑测试
│   └── data_verification/     # 数据验证脚本
│       └── check_data_consistency.sql  # 数据一致性校验（外键、人数联动等）
├── .gitignore                 # Git忽略文件：排除日志、临时文件、敏感配置等
├── README.md                  # 仓库说明：项目介绍、目录结构、使用指南
└── CHANGELOG.md               # 变更日志：记录数据库结构/脚本的迭代历史
```

## 需求分析

## 概念结构设计 (ER图)

## 逻辑结构设计 (关系结构, 表)

## 物理结构设计 (无)

## 数据库实施 (MySQL 代码实现, 数据插入, 数据库运行)

### 触发器、存储过程/函数
