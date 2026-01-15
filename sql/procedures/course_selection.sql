DELIMITER //

-- 统计各选科组合人数
DROP PROCEDURE IF EXISTS GroupStatistics //
CREATE PROCEDURE GroupStatistics()
BEGIN
    SELECT 
        CONCAT(two_choose_one, '-', four_choose_two) AS combination_name,
        SUM(CASE WHEN choose_status = '已确认' THEN 1 ELSE 0 END) AS '已确认人数',
        SUM(CASE WHEN choose_status = '待确认' THEN 1 ELSE 0 END) AS '待确认人数',
        SUM(CASE WHEN choose_status = '需调整' THEN 1 ELSE 0 END) AS '需调整人数',
        COUNT(*) AS '总人数'
    FROM student_course_choose
    GROUP BY two_choose_one, four_choose_two
    ORDER BY '已确认人数' DESC;
END //


-- 为达到开班阈值的班级分班
DROP PROCEDURE IF EXISTS CheckSubjectCombinationThreshold //
CREATE PROCEDURE CheckSubjectCombinationThreshold()
BEGIN
    -- === 基础变量 ===
    DECLARE v_combination_name VARCHAR(100);
    DECLARE v_student_count INT;
    DECLARE v_class_name VARCHAR(50);
    DECLARE new_class_id VARCHAR(20);
    DECLARE counter INT DEFAULT 1;
    DECLARE v_two_choose_one VARCHAR(50);
    DECLARE v_four_choose_two VARCHAR(50);
    -- === 分班算法专用变量 ===
    DECLARE num_classes_needed INT; -- 最终决定的班级数 (Best g)
    DECLARE current_class_size INT;
    DECLARE base_size INT;
    DECLARE extra_count INT;
    DECLARE i INT;
    DECLARE total_class INT DEFAULT 1;
    -- === 算法搜索过程变量 ===
    DECLARE v_min_g INT;
    DECLARE v_max_g INT;
    DECLARE v_search_g INT;
    DECLARE v_found_perfect BOOLEAN;
    
    DECLARE v_low_g INT;
    DECLARE v_high_g INT;
    DECLARE v_best_violation INT;
    DECLARE v_current_violation INT;
    DECLARE v_size_large INT; -- base + 1 的班级人数
    DECLARE v_size_small INT; -- base 的班级人数
    DECLARE v_rem INT;        -- 人数多1的班级数量
    DECLARE v_penalty INT;
    -- === 遍历控制变量 ===
    DECLARE v_total_groups INT DEFAULT 0;
    DECLARE v_curr_group_idx INT DEFAULT 1;

    -- 1. 创建临时表存储快照 (Snapshot)
    DROP TEMPORARY TABLE IF EXISTS temp_process_list;
    CREATE TEMPORARY TABLE temp_process_list (
        id INT AUTO_INCREMENT PRIMARY KEY,
        two_choose_one VARCHAR(50),
        four_choose_two VARCHAR(50),
        combination_name VARCHAR(100),
        student_count INT
    );

    -- 2. 插入数据 (只处理 >= 40 人的)
    INSERT INTO temp_process_list (two_choose_one, four_choose_two, combination_name, student_count)
    SELECT 
        two_choose_one,
        four_choose_two,
        CONCAT(two_choose_one, '-', four_choose_two),
        COUNT(*)
    FROM student_course_choose 
    WHERE choose_status = '已确认'
    GROUP BY two_choose_one, four_choose_two
    HAVING COUNT(*) >= 40;

    SELECT COUNT(*) INTO v_total_groups FROM temp_process_list;
    
    -- 3. 结果统计表
    DROP TEMPORARY TABLE IF EXISTS temp_combination_stats;
    CREATE TEMPORARY TABLE temp_combination_stats (
        combination_name VARCHAR(100),
        total_student_count INT,
        class_id VARCHAR(20),
        class_size INT,
        status VARCHAR(20)
    );

    -- 4. 主循环：处理每一个选科组合
    process_loop: WHILE v_curr_group_idx <= v_total_groups DO
        
        -- 获取当前组合数据
        SELECT two_choose_one, four_choose_two, combination_name, student_count 
        INTO v_two_choose_one, v_four_choose_two, v_combination_name, v_student_count
        FROM temp_process_list 
        WHERE id = v_curr_group_idx;

        --  分班算法实现 START
        SET num_classes_needed = 1; -- 默认兜底
        SET v_found_perfect = FALSE;
        
        -- Case 1: 人数 <= 0 (不处理，直接跳过分班逻辑)
        IF v_student_count <= 0 THEN
            SET num_classes_needed = 0;
            
        -- Case 2: 人数 < 40，强制分1班
        ELSEIF v_student_count < 40 THEN
            SET num_classes_needed = 1;
            
        ELSE
            -- Case 3: 尝试寻找 [40, 50] 的完美解
            -- min_groups = math.ceil(a / 50)
            SET v_min_g = CEIL(v_student_count / 50);
            -- max_groups = a // 40
            SET v_max_g = FLOOR(v_student_count / 40);
            
            SET v_search_g = v_min_g;
            
            perfect_search: WHILE v_search_g <= v_max_g DO
                SET base_size = FLOOR(v_student_count / v_search_g);
                SET v_rem = v_student_count % v_search_g;
                
                -- 大班人数 = base + 1, 小班人数 = base
                -- 检查是否所有班级都在 [40, 50] 之间
                -- 因为 base+1 >= base，只要检查 (base >= 40) 和 (base+1 <= 50) 即可
                -- 但还要考虑余数为0的情况，此时最大也是 base
                
                SET v_size_small = base_size;
                IF v_rem > 0 THEN
                    SET v_size_large = base_size + 1;
                ELSE
                    SET v_size_large = base_size;
                END IF;
                
                IF v_size_small >= 40 AND v_size_large <= 50 THEN
                    SET num_classes_needed = v_search_g;
                    SET v_found_perfect = TRUE;
                    LEAVE perfect_search; -- 找到完美解，退出内层循环
                END IF;
                
                SET v_search_g = v_search_g + 1;
            END WHILE;
            
            -- Case 4: 如果没找到完美解，寻找违规分最低的 (Best Violation)
            IF NOT v_found_perfect THEN
                -- low_g = max(1, math.floor(a / 50) - 2)
                SET v_low_g = FLOOR(v_student_count / 50) - 2;
                IF v_low_g < 1 THEN SET v_low_g = 1; END IF;
                
                -- high_g = min(a, math.ceil(a / 40) + 2)
                SET v_high_g = CEIL(v_student_count / 40) + 2;
                IF v_high_g > v_student_count THEN SET v_high_g = v_student_count; END IF;
                
                SET v_best_violation = 99999999; -- 相当于 float('inf')
                SET num_classes_needed = 1;      -- 默认值
                
                SET v_search_g = v_low_g;
                
                violation_search: WHILE v_search_g <= v_high_g DO
                    SET base_size = FLOOR(v_student_count / v_search_g);
                    SET v_rem = v_student_count % v_search_g; -- 有多少个大班
                    
                    SET v_size_large = base_size + 1;
                    SET v_size_small = base_size;
                    
                    SET v_current_violation = 0;
                    
                    -- 计算大班部分的违规分 (有 v_rem 个)
                    SET v_penalty = 0;
                    IF v_size_large < 40 THEN SET v_penalty = 40 - v_size_large;
                    ELSEIF v_size_large > 50 THEN SET v_penalty = v_size_large - 50;
                    END IF;
                    SET v_current_violation = v_current_violation + (v_penalty * v_rem);
                    
                    -- 计算小班部分的违规分 (有 search_g - rem 个)
                    SET v_penalty = 0;
                    IF v_size_small < 40 THEN SET v_penalty = 40 - v_size_small;
                    ELSEIF v_size_small > 50 THEN SET v_penalty = v_size_small - 50;
                    END IF;
                    SET v_current_violation = v_current_violation + (v_penalty * (v_search_g - v_rem));
                    
                    -- 比较更新最优解
                    IF v_current_violation < v_best_violation THEN
                        SET v_best_violation = v_current_violation;
                        SET num_classes_needed = v_search_g;
                    END IF;
                    
                    SET v_search_g = v_search_g + 1;
                END WHILE;
            END IF; -- End of Case 4
            
        END IF; 


        SELECT CONCAT('Processing: ', v_combination_name, ' (', v_student_count, '人) -> 分 ', num_classes_needed, ' 班') AS Algorithm_Log;

        IF num_classes_needed > 0 THEN
            -- 重新计算 base_size 和 extra_count 用于具体的学生分配
            SET base_size = FLOOR(v_student_count / num_classes_needed);
            SET extra_count = v_student_count % num_classes_needed;
            
            -- 1. 锁定学生状态
            UPDATE student_course_choose
            SET choose_status = '处理中'
            WHERE two_choose_one = v_two_choose_one
            AND four_choose_two = v_four_choose_two
            AND choose_status = '已确认';
            
            -- 2. 循环创建班级并分配
            SET i = 1;
            WHILE i <= num_classes_needed DO
                
                -- 确定本班人数
                IF i <= extra_count THEN
                    SET current_class_size = base_size + 1;
                ELSE
                    SET current_class_size = base_size;
                END IF;
                
                -- 生成班级ID和名称
                SET new_class_id = CONCAT('C2', LPAD(counter, 2, '0'));
                SET v_class_name = CONCAT('高二', total_class, '班');
                SET total_class = total_class + 1;
                SET counter = counter + 1;
                
                -- 插入班级表
                INSERT IGNORE INTO class (class_id, class_name, grade, subject_combination, current_student_num, create_time)
                VALUES (new_class_id, v_class_name, 2, v_combination_name, current_class_size, CURRENT_TIMESTAMP);
                
                -- 分配学生 (利用 LIMIT 控制人数)
                UPDATE student_course_choose
                SET class_id = new_class_id, choose_status = '已分班'
                WHERE two_choose_one = v_two_choose_one
                AND four_choose_two = v_four_choose_two
                AND choose_status = '处理中'
                LIMIT current_class_size;
                
                -- 同步 student 表 (利用索引加速)
                UPDATE student s
                INNER JOIN student_course_choose scc ON s.student_id = scc.student_id
                SET s.class_id = new_class_id, grade = 2
                WHERE scc.class_id = new_class_id;
                
                -- 记录结果
                INSERT INTO temp_combination_stats
                VALUES (v_combination_name, v_student_count, new_class_id, current_class_size, '已开班');
                
                SET i = i + 1;
            END WHILE;
            
        END IF; -- End if num_classes > 0
        
        -- 处理下一组
        SET v_curr_group_idx = v_curr_group_idx + 1;
        
    END WHILE;

    -- 最终输出
    SELECT * FROM temp_combination_stats ORDER BY combination_name, class_id;
    
    -- 清理
    DROP TEMPORARY TABLE IF EXISTS temp_process_list;
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

-- 调用示例
-- CALL HandleInsufficientCombination(); -- 选出"需调整"的学生标注
-- CALL AdjustStudentCourseSelection('S000001', '历史', '政治,生物') -- 手动调整学生选课并确认

-- update student_course_choose set choose_status = '已确认', class_id = NULL; -- 截止时间到，就绪
-- CALL CheckSubjectCombinationThreshold() -- 正式分班
