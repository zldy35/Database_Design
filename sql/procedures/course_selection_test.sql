-- 测试数据和存储过程调用示例

-- 1. 插入测试学生数据
INSERT INTO student (student_id, student_name, gender, grade, class_id, high1_class_id) VALUES
('S001', '张三', '男', 1, 'C001', 'C001'),
('S002', '李四', '女', 1, 'C001', 'C001'),
('S003', '王五', '男', 1, 'C001', 'C001'),
('S004', '赵六', '女', 1, 'C002', 'C002'),
('S005', '钱七', '男', 1, 'C002', 'C002'),
('S006', '孙八', '女', 1, 'C002', 'C002'),
('S007', '周九', '男', 1, 'C003', 'C003'),
('S008', '吴十', '女', 1, 'C003', 'C003'),
('S009', '郑一', '男', 1, 'C003', 'C003'),
('S010', '王二', '女', 1, 'C003', 'C003');

-- 2. 插入测试选课数据
INSERT INTO student_course_choose (student_id, one_choose_one, four_choose_two) VALUES
('S001', '物理', '政治,地理'),
('S002', '物理', '政治,地理'),
('S003', '物理', '政治,地理'),
('S004', '物理', '政治,地理'),
('S005', '物理', '政治,地理'),
('S006', '物理', '政治,地理'),
('S007', '历史', '政治,地理'),
('S008', '历史', '政治,地理'),
('S009', '历史', '政治,地理'),
('S010', '历史', '政治,地理');

-- 测试1: 检查选科组合阈值（设置最低开班人数为3）
CALL CheckSubjectCombinationThreshold(3);

-- 测试2: 调整学生选课
CALL AdjustStudentCourseSelection('S001', '物理', '化学,生物');

-- 测试后再次检查选科组合阈值
CALL CheckSubjectCombinationThreshold(3);

-- 测试3: 处理人数不足的选科组合
CALL HandleInsufficientCombination();

-- 测试4: 使用函数获取特定选科组合人数
SELECT GetSubjectCombinationCount('物理', '政治,地理') AS 物理政治地理组合人数;
SELECT GetSubjectCombinationCount('历史', '政治,地理') AS 历史政治地理组合人数;
