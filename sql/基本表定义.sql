CREATE DATABASE IF NOT EXISTS Database_Design DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE Database_Design;


-- 1. 账号密码表 account
CREATE TABLE account(
    person_id VARCHAR(20) PRIMARY KEY COMMENT '对应用户',
    password VARCHAR(20) NOT NULL COMMENT '密码',
)COMMENT '账号密码';


-- 2. 角色表 role
CREATE TABLE role (
    role_id VARCHAR(20) NOT NULL COMMENT '角色编号',
    role_name ENUM('学生', '班主任', '科任老师', '教务主任', '校长') NOT NULL COMMENT '角色名称',
    role_desc VARCHAR(200) COMMENT '角色描述',
    PRIMARY KEY (role_id)
) COMMENT '系统角色表';

-- 初始化角色数据
INSERT INTO role VALUES 
('R001', '学生', '仅可查看本人课表和成绩'),
('R002', '班主任', '可查看本班课表和全体学生成绩'),
('R003', '科任老师', '可查看所教班级课表和对应课程成绩'),
('R004', '教务主任', '负责分班管理和全校数据查看'),
('R005', '校长', '继承教务主任权限,管理教职工信息');


-- 3. 课程表 course
CREATE TABLE course (
    course_id VARCHAR(20) NOT NULL COMMENT '课程编号',
    course_name VARCHAR(50) NOT NULL COMMENT '课程名称',
    course_type ENUM('主科', '主选科', '副选科') NOT NULL COMMENT '课程类型',
    is_score_convert ENUM('是', '否') NOT NULL COMMENT '是否参与赋分(仅政史地生为是)',
    PRIMARY KEY (course_id)
) COMMENT '高中课程信息表';

-- 初始化9门课程数据（主科：语数外；选科：理化生政史地）
INSERT INTO course VALUES 
('C001', '语文', '主科', '否'),
('C002', '数学', '主科', '否'),
('C003', '英语', '主科', '否'),
('C004', '物理', '主选科', '否'),
('C005', '化学', '主选科', '否'),
('C006', '生物', '副选科', '是'),
('C007', '政治', '副选科', '是'),
('C008', '历史', '副选科', '是'),
('C009', '地理', '副选科', '是');


-- 4. 教职工表 staff
CREATE TABLE staff (
    staff_id VARCHAR(20) NOT NULL COMMENT '工号',
    staff_name VARCHAR(50) NOT NULL COMMENT '教职工姓名',
    gender ENUM('男', '女') NOT NULL COMMENT '性别',
    position VARCHAR(50) NOT NULL COMMENT '职称',
    is_leave ENUM('是', '否') NOT NULL DEFAULT '否' COMMENT '是否离职',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '录入时间',
    PRIMARY KEY (staff_id),
    FOREIGN KEY(staff_id) REFERENCES account(person_id)
) COMMENT '教职工信息表';


-- 5. 班级表 class
CREATE TABLE class (
    class_id VARCHAR(20) NOT NULL COMMENT '班级编号',
    class_name VARCHAR(50) NOT NULL COMMENT '班级名称',
    grade INT NOT NULL COMMENT '年级(1:高一 2:高二 3:高三)',
    subject_combination VARCHAR(100) COMMENT '选科组合',
    head_teacher_id VARCHAR(20) COMMENT '班主任工号',
    current_student_num INT NOT NULL DEFAULT 0 COMMENT '当前班级人数',
    create_time VARCHAR(20) NOT NULL,
    PRIMARY KEY (class_id),
    -- 新增外键约束，关联教职工表，确保班主任工号合法有效
    FOREIGN KEY (head_teacher_id) REFERENCES staff(staff_id) 
        ON UPDATE CASCADE 
        ON DELETE RESTRICT
) COMMENT '班级信息表';


-- 6. 学生表 student
CREATE TABLE student (
    student_id VARCHAR(20) NOT NULL COMMENT '学号',
    student_name VARCHAR(50) NOT NULL COMMENT '学生姓名',
    gender ENUM('男', '女') NOT NULL COMMENT '性别',
    grade INT NOT NULL COMMENT '年级',
    class_id VARCHAR(20) NOT NULL COMMENT '当前所在班级编号',
    high1_class_id VARCHAR(20) NOT NULL COMMENT '高一行政班编号',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '录入时间',
    PRIMARY KEY (student_id),
    FOREIGN KEY (class_id) REFERENCES class(class_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (high1_class_id) REFERENCES class(class_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY(student_id) REFERENCES account(person_id)
) COMMENT '学生信息表';


-- 7. 角色关联表 account_role (支持班主任+科任老师兼任)
CREATE TABLE account_role (
    id INT NOT NULL AUTO_INCREMENT COMMENT '关联记录ID',
    account_id VARCHAR(20) NOT NULL COMMENT '工号',
    role_id VARCHAR(20) NOT NULL COMMENT '角色编号',
    PRIMARY KEY (id),
    UNIQUE KEY uk_staff_role (account_id, role_id),
    FOREIGN KEY (account_id) REFERENCES account(person_id) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES role(role_id) ON UPDATE CASCADE ON DELETE RESTRICT
) COMMENT '角色关联表';


-- 8. 选课记录表 student_course_choose
CREATE TABLE student_course_choose (
    id INT NOT NULL AUTO_INCREMENT COMMENT '选课记录ID',
    student_id VARCHAR(20) NOT NULL COMMENT '学号',
    main_course VARCHAR(100) NOT NULL DEFAULT '语文,数学,英语' COMMENT '主科组合(固定)',
    two_choose_one ENUM('物理', '历史') NOT NULL COMMENT '物理/历史二选一',
    four_choose_two VARCHAR(50) NOT NULL COMMENT '政史地生四选二(如政治,地理)',
    class_id VARCHAR(20) COMMENT '分配的选科班编号',
    choose_status ENUM('待确认', '已确认', '需调整') NOT NULL DEFAULT '待确认' COMMENT '选课状态',
    choose_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '选课时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_student_choose (student_id),
    FOREIGN KEY (student_id) REFERENCES student(student_id) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (class_id) REFERENCES class(class_id) ON UPDATE CASCADE ON DELETE SET NULL
) COMMENT '高二学生选科记录表';


-- 9. 考试信息表 exam
CREATE TABLE exam (
    exam_id VARCHAR(20) NOT NULL COMMENT '考试编号',
    exam_name VARCHAR(100) NOT NULL COMMENT '考试名称',
    exam_time DATETIME NOT NULL COMMENT '考试时间',
    valid_exam_num INT COMMENT '单科有效参考人数',
    remark VARCHAR(200) COMMENT '备注',
    PRIMARY KEY (exam_id)
) COMMENT '考试信息表';


-- 10. 考试成绩表 exam_score (存储原始分+赋分,关联市排名)
CREATE TABLE exam_score (
    id INT NOT NULL AUTO_INCREMENT COMMENT '成绩记录ID',
    exam_id VARCHAR(20) NOT NULL COMMENT '考试编号',
    student_id VARCHAR(20) NOT NULL COMMENT '学号',
    course_id VARCHAR(20) NOT NULL COMMENT '课程编号',
    original_score DECIMAL(5,2) NOT NULL COMMENT '原始分数',
    convert_score DECIMAL(5,2) COMMENT '赋分分数(政史地生)',
    course_rank INT COMMENT '单科排名',
    PRIMARY KEY (id),
    UNIQUE KEY uk_exam_student_course (exam_id, student_id, course_id),
    FOREIGN KEY (exam_id) REFERENCES exam(exam_id) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES student(student_id) ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (course_id) REFERENCES course(course_id) ON UPDATE CASCADE ON DELETE RESTRICT
) COMMENT '学生考试成绩表';


