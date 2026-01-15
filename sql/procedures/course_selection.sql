-- 统计各选科组合人数
SELECT 
    CONCAT(two_choose_one, '-', four_choose_two) AS combination_name,
    SUM(CASE WHEN choose_status = '已确认' THEN 1 ELSE 0 END) AS '已确认人数',
    SUM(CASE WHEN choose_status = '待确认' THEN 1 ELSE 0 END) AS '待确认人数',
    SUM(CASE WHEN choose_status = '需调整' THEN 1 ELSE 0 END) AS '需调整人数',
    COUNT(*) AS '总人数'
FROM student_course_choose
GROUP BY two_choose_one, four_choose_two
ORDER BY '已确认人数' DESC;


DELIMITER //

-- 为达到开班阈值的班级分班
CREATE PROCEDURE CheckSubjectCombinationThreshold()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_combination_name VARCHAR(100);
    DECLARE v_student_count INT;
    DECLARE v_class_name VARCHAR(50);
    DECLARE new_class_id VARCHAR(20);
    DECLARE counter INT DEFAULT 1;
    DECLARE v_two_choose_one ENUM('物理', '历史');
    DECLARE v_four_choose_two VARCHAR(50);
    DECLARE num_classes_needed INT;
    DECLARE current_class_size INT;
    DECLARE base_size INT;
    DECLARE extra_count INT;
    DECLARE i INT DEFAULT 1;
    DECLARE min_class_size INT DEFAULT 40;  -- 最低开班人数阈值
    DECLARE max_class_size INT DEFAULT 50;   -- 每班人数上限
    
    -- 声明游标，用于遍历选科组合统计结果
    DECLARE combination_cursor CURSOR FOR 
        SELECT 
            two_choose_one,
            four_choose_two,
            CONCAT(two_choose_one, '-', four_choose_two) AS combination_name,
            COUNT(*) AS student_count
        FROM student_course_choose 
        WHERE choose_status = '已确认'
        GROUP BY two_choose_one, four_choose_two
        HAVING COUNT(*) >= 40;  -- 只处理选择人数大于等于40人的选课组合
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- 创建临时表存储统计结果
    DROP TEMPORARY TABLE IF EXISTS temp_combination_stats;
    CREATE TEMPORARY TABLE temp_combination_stats (
        combination_name VARCHAR(100),
        total_student_count INT,
        class_id VARCHAR(20),
        class_size INT,
        status VARCHAR(20)
    );
    
    -- 打开游标
    OPEN combination_cursor;
    
    read_loop: LOOP
        FETCH combination_cursor INTO v_two_choose_one, v_four_choose_two, v_combination_name, v_student_count;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- 根据Python算法计算最优分班方案：使每班人数尽可能在40~50之间
        -- 计算合理的班级数量：从1到总人数，但重点关注总人数/50到总人数/40的范围
        SET num_classes_needed = CEIL(v_student_count / max_class_size);
        -- 如果按最大容量计算的班级数会导致某些班级人数少于最小值，则增加班级数来平衡人数
        WHILE (FLOOR(v_student_count / num_classes_needed) < min_class_size AND num_classes_needed > 1) DO
            SET num_classes_needed = num_classes_needed + 1;
        END WHILE;
        
        -- 基本每个班的人数 = 总人数 ÷ 班级数
        SET base_size = FLOOR(v_student_count / num_classes_needed);
        -- 需要额外分配的学生数 = 总人数 % 班级数
        SET extra_count = v_student_count % num_classes_needed;
        
        -- 更新学生选课记录状态为处理中，避免重复处理
        UPDATE student_course_choose
        SET choose_status = '处理中'
        WHERE two_choose_one = v_two_choose_one
        AND four_choose_two = v_four_choose_two
        AND choose_status = '已确认';
        
        -- 创建所需数量的班级并分配学生
        SET i = 1;
        
        WHILE i <= num_classes_needed DO
            -- 确定当前班级的大小：前extra_count个班级多分配1人，其余为基本人数
            IF i <= extra_count THEN
                SET current_class_size = base_size + 1;
            ELSE
                SET current_class_size = base_size;
            END IF;
            
            -- 生成新班级ID和名称
            SET new_class_id = CONCAT('CL', LPAD(counter, 4, '0'));
            SET v_class_name = CONCAT('高二', v_combination_name, '班', i);
            SET counter = counter + 1;
            
            -- 创建班级
            INSERT IGNORE INTO class (class_id, class_name, grade, current_student_num)
            VALUES (new_class_id, v_class_name, 2, current_class_size);
            
            -- 为当前班级分配指定数量的学生
            UPDATE student_course_choose
            SET class_id = new_class_id, choose_status = '已确认'
            WHERE two_choose_one = v_two_choose_one
            AND four_choose_two = v_four_choose_two
            AND choose_status = '处理中'
            LIMIT current_class_size;
            
            -- 更新学生表中的当前班级
            UPDATE student s
            JOIN student_course_choose scc ON s.student_id = scc.student_id
            SET s.class_id = new_class_id
            WHERE scc.class_id = new_class_id AND scc.two_choose_one = v_two_choose_one AND scc.four_choose_two = v_four_choose_two;
            
            -- 记录到统计结果表
            INSERT INTO temp_combination_stats
            VALUES (
                v_combination_name,
                v_student_count,
                new_class_id,
                current_class_size,
                '已开班'
            );
            
            SET i = i + 1;
        END WHILE;
    END LOOP;
    
    CLOSE combination_cursor;
    
    -- 将处理完的选课记录状态从'处理中'改回'已确认'
    UPDATE student_course_choose
    SET choose_status = '已确认'
    WHERE choose_status = '处理中';
    
    -- 返回统计结果
    SELECT * FROM temp_combination_stats ORDER BY combination_name, class_id;
    
    -- 清理临时表
    DROP TEMPORARY TABLE IF EXISTS temp_combination_stats;
    
END //


-- 学生选课调整
DROP PROCEDURE IF EXISTS AdjustStudentCourseSelection //
CREATE PROCEDURE AdjustStudentCourseSelection(
    IN p_student_id VARCHAR(20),
    IN p_two_choose_one ENUM('物理', '历史'),
    IN p_four_choose_two VARCHAR(50)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    -- 更新学生的选课记录
    UPDATE student_course_choose
    SET 
        two_choose_one = p_two_choose_one,
        four_choose_two = p_four_choose_two,
        choose_status = '已确认',
        choose_time = CURRENT_TIMESTAMP
    WHERE student_id = p_student_id;
    
    -- 检查是否成功更新
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '学生选课记录未找到';
    END IF;
    
    COMMIT;
END //


-- 处理人数不足的选科组合，提醒学生重新选择
DROP PROCEDURE IF EXISTS HandleInsufficientCombination //
CREATE PROCEDURE HandleInsufficientCombination()
BEGIN
    -- 将人数不足的选科组合状态设置为"需调整"，要求学生重新选课
    UPDATE student_course_choose scc
    JOIN (
        SELECT 
            CONCAT(two_choose_one, '-', four_choose_two) AS combination_name,
            COUNT(*) AS student_count
        FROM student_course_choose
        WHERE choose_status = '已确认'
        GROUP BY two_choose_one, four_choose_two
        HAVING COUNT(*) < 40  -- 低于开班阈值40人
    ) insufficient ON CONCAT(scc.two_choose_one, '-', scc.four_choose_two) = insufficient.combination_name
    SET scc.choose_status = '需调整'
    WHERE scc.choose_status = '已确认';
    
    -- 返回需要调整选课的学生信息
    SELECT 
        s.student_id,
        s.student_name,
        scc.two_choose_one,
        scc.four_choose_two,
        scc.choose_status
    FROM student s
    JOIN student_course_choose scc ON s.student_id = scc.student_id
    WHERE scc.choose_status = '需调整';
END //

DELIMITER ;


call HandleInsufficientCombination(); -- 选出"需调整"的学生标注
call AdjustStudentCourseSelection('S000001', '历史', '政治,生物') -- 手动调整学生选课并确认
