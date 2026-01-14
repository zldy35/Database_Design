USE Database_Design;
-- 关闭外键约束检查（生成数据时临时关闭，生成完成自动恢复）
SET FOREIGN_KEY_CHECKS = 0;
-- 清空所有相关表数据（按外键关联倒序清空，避免报错）
TRUNCATE TABLE exam_score;
TRUNCATE TABLE exam;
TRUNCATE TABLE student_course_choose;
TRUNCATE TABLE student;
TRUNCATE TABLE class;
TRUNCATE TABLE account_role;
TRUNCATE TABLE staff;
TRUNCATE TABLE account;
-- 恢复外键约束
SET FOREIGN_KEY_CHECKS = 1;

DELIMITER $$
DROP FUNCTION IF EXISTS get_rand_name $$
CREATE FUNCTION get_rand_name(gender CHAR(1)) RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    -- 你的原姓名库完全不变，一个字都不用改
    DECLARE family_names VARCHAR(500) DEFAULT '赵钱孙李周吴郑王冯陈褚卫蒋沈韩杨朱秦尤许何吕施张孔曹严华金魏陶姜';
    DECLARE boy_names VARCHAR(500) DEFAULT '伟磊鹏杰浩宇轩泽晨航俊彦哲博睿鑫铭霖泽宸梓涵昱泽沐辰奕辰瑾瑜';
    DECLARE girl_names VARCHAR(500) DEFAULT '婷妍娜慧娟颖瑶怡欣玥琪萱菲琳梓涵雨桐诗琪语萱一诺欣怡梦瑶思涵';
    DECLARE rand_family VARCHAR(2);
    DECLARE rand_given VARCHAR(2);
    
    -- ========== 完美修复核心：用MID函数，精准截取1个中文，随机数边界精准匹配 ==========
    -- 姓氏库共20个姓氏 → 随机取 1-20 的位置，截取1个中文
    SET rand_family = MID(family_names, FLOOR(1 + RAND() * 20), 1);
    -- 男孩/女孩名字库各20个字 → 随机取 1-20 的位置，截取1个中文
    IF gender = '男' THEN
        SET rand_given = MID(boy_names, FLOOR(1 + RAND() * 20), 1);
    ELSE
        SET rand_given = MID(girl_names, FLOOR(1 + RAND() * 20), 1);
    END IF;
    
    -- 姓+名 组合，百分百有值，再也不会空名！
    RETURN CONCAT(rand_family, rand_given);
END $$

-- 函数2：随机生成教师职称
DROP FUNCTION IF EXISTS get_rand_position $$
CREATE FUNCTION get_rand_position() RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    DECLARE positions VARCHAR(100) DEFAULT '高级教师,一级教师,二级教师';
    RETURN SUBSTRING_INDEX(SUBSTRING_INDEX(positions, ',', FLOOR(1 + RAND()*3)), ',', -1);
END $$
DELIMITER ;

DELIMITER $$
DROP PROCEDURE IF EXISTS proc_generate_highschool_data $$
CREATE PROCEDURE proc_generate_highschool_data()
BEGIN
    -- ========== 变量声明区 ==========
    DECLARE i INT DEFAULT 1;  
    DECLARE j INT DEFAULT 2;
    DECLARE k INT DEFAULT 4;   
    DECLARE z INT DEFAULT 1;           -- 循环计数器
    DECLARE stu_count INT DEFAULT 900; -- 高一学生总数
    DECLARE tea_count INT DEFAULT 40;   -- 科任/班主任老师总数
    DECLARE dean_count INT DEFAULT 2;   -- 教务主任总数
    DECLARE head_count INT DEFAULT 1;   -- 校长总数
    DECLARE rand_gender CHAR(1);        -- 随机性别
    DECLARE rand_name VARCHAR(50);      -- 随机姓名
    DECLARE class_id VARCHAR(20);       -- 班级编号
    DECLARE class_name VARCHAR(50);     -- 班级名称
    DECLARE ht_id VARCHAR(20);          -- 班主任工号

    -- ========== 一、生成【1个校长】数据 ==========
    SET rand_gender = IF(RAND()>0.6, '男', '女'); -- 校长大概率为男性
    SET rand_name = get_rand_name(rand_gender);
    -- 插入账号表 (工号T开头，6位补零)
    INSERT INTO account (person_id, password) VALUES (CONCAT('T', LPAD(1, 6, 0)), '123456');
    -- 插入教职工表
    INSERT INTO staff (staff_id, staff_name, gender, position, is_leave) 
    VALUES (CONCAT('T', LPAD(1, 6, 0)), rand_name, rand_gender, '校长', '否');
    -- 绑定角色：校长 R005
    INSERT INTO account_role (account_id, role_id) VALUES (CONCAT('T', LPAD(1, 6, 0)), 'R005');


    -- ========== 二、生成【2个教务主任】数据 ==========
    WHILE j <= head_count + dean_count DO
        SET rand_gender = IF(RAND()>0.5, '男', '女');
        SET rand_name = get_rand_name(rand_gender);
        INSERT INTO account (person_id, password) VALUES (CONCAT('T', LPAD(j, 6, 0)), '123456');
        INSERT INTO staff (staff_id, staff_name, gender, position, is_leave) 
        VALUES (CONCAT('T', LPAD(j, 6, 0)), rand_name, rand_gender, '教务主任', '否');
        -- 绑定角色：教务主任 R004
        INSERT INTO account_role (account_id, role_id) VALUES (CONCAT('T', LPAD(j, 6, 0)), 'R004');
        SET j = j + 1;
    END WHILE;

    -- ========== 三、生成【40个教师】数据 (前10个为班主任+科任老师，后30个仅科任老师) ==========
    WHILE k <= head_count + dean_count + tea_count DO
        SET rand_gender = IF(RAND()>0.5, '男', '女');
        SET rand_name = get_rand_name(rand_gender);
        -- 插入账号表
        INSERT INTO account (person_id, password) VALUES (CONCAT('T', LPAD(k, 6, 0)), '123456');
        -- 插入教职工表
        INSERT INTO staff (staff_id, staff_name, gender, position, is_leave) 
        VALUES (CONCAT('T', LPAD(k, 6, 0)), rand_name, rand_gender, get_rand_position(), '否');
        -- 前10个教师 绑定【班主任 R002 + 科任老师 R003】双角色（支持兼任，无重复唯一键）
        IF k <= head_count + dean_count + 20 THEN
            INSERT INTO account_role (account_id, role_id) VALUES (CONCAT('T', LPAD(k,6,0)), 'R002');
            INSERT INTO account_role (account_id, role_id) VALUES (CONCAT('T', LPAD(k,6,0)), 'R003');
        ELSE
            -- 后30个教师 仅绑定【科任老师 R003】角色
            INSERT INTO account_role (account_id, role_id) VALUES (CONCAT('T', LPAD(k,6,0)), 'R003');
        END IF;
        SET k = k + 1;
    END WHILE;

    -- ========== 四、生成【高一10个行政班】数据 ==========
    SET z = 1;
    WHILE z <= 20 DO
        SET class_id = CONCAT('C1', LPAD(z, 2, 0)); -- 班级编号 C101-C110 (1代表高一)
        SET class_name = CONCAT('高一', z, '班');
        -- 班主任工号精准对应：校长(1)+主任(2) 之后的第1-10个老师，就是班主任
        SET ht_id = CONCAT('T', LPAD(head_count + dean_count + z, 6, 0)); 
        INSERT INTO class (class_id, class_name, grade, subject_combination, head_teacher_id, current_student_num, create_time)
        VALUES (class_id, class_name, 1, '高一行政班，暂无选科', ht_id, 100, DATE_FORMAT(NOW(), '%Y-%m-%d'));
        SET z = z + 1;
    END WHILE;

    -- ========== 五、生成【1000个高一学生】数据 ==========
    SET i = 1;
    WHILE i <= stu_count DO
        SET rand_gender = IF(RAND()>0.5, '男', '女');
        SET rand_name = get_rand_name(rand_gender);
        -- 平均分班：1-100→C101，101-200→C102 ... 901-1000→C110，每班严格100人
        SET class_id = CONCAT('C1', LPAD(CEIL(i/50), 2, 0)); 
        -- 插入账号表 (学号S开头，6位补零)
        INSERT INTO account (person_id, password) VALUES (CONCAT('S', LPAD(i, 6, 0)), '123456');
        -- 插入学生表：高一grade=1，行政班和当前班一致
        INSERT INTO student (student_id, student_name, gender, grade, class_id, high1_class_id)
        VALUES (CONCAT('S', LPAD(i, 6, 0)), rand_name, rand_gender, 1, class_id, class_id);
        -- 绑定角色：学生 R001
        INSERT INTO account_role (account_id, role_id) VALUES (CONCAT('S', LPAD(i, 6, 0)), 'R001');
        SET i = i + 1;
    END WHILE;


END $$
DELIMITER ;

USE Database_Design;
CALL proc_generate_highschool_data();