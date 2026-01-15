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
│   │   ├── 01_score_convert_func.sql   # 政地生化赋分计算函数
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

### 索引
创建精准的复合索引（最关键！）
根据你的查询场景，建议添加以下索引：


-- 1. 按考试查成绩（最常用）
CREATE INDEX idx_exam ON exam_score(exam_id);

-- 2. 按学生查所有成绩（个人成绩单）
CREATE INDEX idx_student ON exam_score(student_id, exam_id);

-- 3. 按课程+考试查（如“本次月考数学成绩”）
CREATE INDEX idx_course_exam ON exam_score(course_id, exam_id);

-- 4. 市排名查询（仅市统考）
CREATE INDEX idx_city_rank ON exam_score(exam_id, city_rank) 
WHERE is_city_rank = '是';  -- MySQL 8.0+ 支持函数索引，否则建普通索引
💡 注意：不要盲目加索引！每个索引会降低写入速度。优先覆盖高频查询。

## 数据库实施 (MySQL 代码实现, 数据插入, 数据库运行)

### 触发器、存储过程/函数

#### 1. 班级与选课管理模块
说明: 高二分班选课



#### 2. 权限管理模块
说明: 角色权限管理(学生、科任老师、班主任、教务主任、校长)

#### 3. 考试与成绩管理模块
说明: 成绩赋分, 成绩更改日志

广州高考实行等级赋分制度，主要针对思想政治、地理、生物和化学四门科目，旨在平衡不同科目的难度差异。
**赋分制度概述**
1. 等级赋分：广州高考的赋分制度将考生的选考科目成绩按从高到低排序，根据考生人数比例划分为五个等级：A、B、C、D、E，各等级人数所占比例分别为15%、35%、35%、13%和2%。 
2. 赋分区间：每个等级对应的分数区间如下：
    A等级：100～86分
    B等级：85～71分
    C等级：70～56分
    D等级：55～41分
    E等级：40～30分。 

**赋分计算方法**
实际实现采用基于排名百分位的等级赋分制：
1. 首先根据学生原始成绩在考试中的排名确定所属等级
2. 然后在等级内根据排名位置计算具体分数
3. 使用RANK()函数处理同分同名次情况

计算公式：
- A等级(前15%)：$T = 100 - \frac{(排名百分位 - 0)}{15} \times 14$
- B等级(16%-50%)：$T = 85 - \frac{(排名百分位 - 15)}{35} \times 14$
- C等级(51%-85%)：$T = 70 - \frac{(排名百分位 - 50)}{35} \times 14$
- D等级(86%-98%)：$T = 55 - \frac{(排名百分位 - 85)}{13} \times 14$
- E等级(后2%)：$T = 40 - \frac{(排名百分位 - 98)}{2} \times 10$

其中，排名百分位 = $\frac{学生排名 \times 100.0}{总人数}$


#### 4. 基础数据管理模块
说明: 学生信息、教职工信息、课程信息、学生学籍日志


### 数据库测试

#### 选课数据插入

成功完成了为高一学生插入选课表数据的任务。具体实现如下：
1. 创建了'test/选课数据插入_最终版.sql'文件，包含完整的存储过程
2. 成功为1000名高一学生插入选课数据
3. 满足了所有要求：
   - 物理/历史二选一比例为6:4（实际为600:400）
   - 政史地生四选二按照要求的顺序排列（政治<地理<生物<化学）
   - "物理"+"政治,地理"组合限制在15人（< 30人）
   - "历史"+"生物,化学"组合限制在15人（< 30人）
4. 所有数据均已正确插入到student_course_choose表中
5. 解决了**存储过程中变量赋值的问题**，使用**用户变量(@variable)**作为中间步骤确保了数据正确获取(使用**本地变量**会出错)

```powershell
PS E:\Columns\courses\database_数据库原理\final_assignment\Database_Design> Get-Content -Encoding UTF8 "test/选课数据插入_最终版.sql" | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-file="C:\ProgramData\MySQL\MySQL Server 8.0\my.ini" -uroot -proot --default-character-set=utf8mb4 --init-command="SET NAMES utf8mb4;"          
mysql: [Warning] Using a password on the command line interface can be insecure.
info
总共需要处理 1000 名高一学生
progress
已处理 100 名学生，当前学生ID: S000100
progress
已处理 200 名学生，当前学生ID: S000200
progress
已处理 300 名学生，当前学生ID: S000300
progress
已处理 400 名学生，当前学生ID: S000400
progress
已处理 500 名学生，当前学生ID: S000500
progress
已处理 600 名学生，当前学生ID: S000600
progress
已处理 700 名学生，当前学生ID: S000700
progress
已处理 800 名学生，当前学生ID: S000800
progress
已处理 900 名学生，当前学生ID: S000900
progress
已处理 1000 名学生，当前学生ID: S001000
summary
数据插入完成，物理:历史 = 600:400，总计 1000 名学生
two_choose_one  four_choose_two student_count
物理    化学,生物       51
物理    地理,化学       96
物理    地理,生物       101
物理    政治,化学       87
物理    政治,地理       15
物理    政治,生物       104
物理    生物,化学       146
历史    地理,化学       65
历史    地理,生物       58
历史    政治,化学       68
历史    政治,地理       120
历史    政治,生物       74
历史    生物,化学       15
PS E:\Columns\courses\database_数据库原理\final_assignment\Database_Design> echo "USE Database_Design; SELECT two_choose_one, four_choose_two, COUNT(*) as student_count FROM student_course_choose WHERE (two_choose_one = '物理' AND four_choose_two = '政治,地理') OR (two_choose_one = '历史' AND four_choose_two = '生物,化学') GROUP BY two_choose_one, four_choose_two;" | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-file="C:\ProgramData\MySQL\MySQL Server 8.0\my.ini" -uroot -proot --default-character-set=utf8mb4 --init-command="SET NAMES utf8mb4;"
mysql: [Warning] Using a password on the command line interface can be insecure.
two_choose_one  four_choose_two student_count
物理    政治,地理       15
历史    生物,化学       15
PS E:\Columns\courses\database_数据库原理\final_assignment\Database_Design> echo "USE Database_Design; SELECT DISTINCT four_choose_two FROM student_course_choose ORDER BY four_choose_two;" | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" --defaults-file="C:\ProgramData\MySQL\MySQL Server 8.0\my.ini" -uroot -proot --default-character-set=utf8mb4 --init-command="SET NAMES utf8mb4;"                                                                                                                                 
mysql: [Warning] Using a password on the command line interface can be insecure.
four_choose_two
化学,生物
地理,化学
地理,生物
政治,化学
政治,地理
政治,生物
生物,化学
```

