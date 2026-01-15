USE Database_Design;

-- 先清除可能存在的数据
TRUNCATE TABLE student_course_choose;

DELIMITER $$

DROP PROCEDURE IF EXISTS proc_generate_course_selection_data $$

CREATE PROCEDURE proc_generate_course_selection_data()
BEGIN
    -- 声明变量
    DECLARE i INT DEFAULT 1;
    DECLARE two_subject VARCHAR(10);
    DECLARE four_subject VARCHAR(50);
    DECLARE physical_count INT DEFAULT 0;
    DECLARE history_count INT DEFAULT 0;
    DECLARE phys_pol_geo_count INT DEFAULT 0;  -- 物理+政治,地理 组合计数
    DECLARE hist_bio_chem_count INT DEFAULT 0; -- 历史+生物,化学 组合计数
    DECLARE total_students INT;
    DECLARE current_student_id VARCHAR(20);
    
    -- 获取高一学生总数
    SELECT COUNT(*) INTO total_students 
    FROM student 
    WHERE grade = 1;
    
    SELECT CONCAT('总共需要处理 ', total_students, ' 名高一学生') AS info;
    
    -- 遍历所有高一学生
    WHILE i <= total_students DO
        -- 使用用户变量获取当前学生ID，然后赋值给本地变量
        SET @student_id := NULL;
        SELECT student_id INTO @student_id
        FROM (
            SELECT student_id, ROW_NUMBER() OVER (ORDER BY student_id) as rn 
            FROM student 
            WHERE grade = 1
        ) AS ranked 
        WHERE rn = i;
        
        SET current_student_id = @student_id;
        
        -- 确保student_id不为NULL
        IF current_student_id IS NOT NULL THEN
            -- 1. 物理/历史二选一 (6:4比例)
            IF physical_count + history_count < total_students THEN
                IF physical_count < total_students * 0.6 AND RAND() <= 0.6 THEN
                    SET two_subject = '物理';
                    SET physical_count = physical_count + 1;
                ELSE
                    IF history_count < total_students * 0.4 THEN
                        SET two_subject = '历史';
                        SET history_count = history_count + 1;
                    ELSE
                        SET two_subject = '物理';  -- 备用情况
                        SET physical_count = physical_count + 1;
                    END IF;
                END IF;
            END IF;
            
            -- 2. 政史地生四选二 (按顺序选择并确保有序)
            SET @subject1 := NULL;
            SET @subject2 := NULL;
            
            -- 随机选择两个不同的选科
            SET @choice1 := FLOOR(1 + RAND() * 4);
            SET @choice2 := FLOOR(1 + RAND() * 4);
            WHILE @choice1 = @choice2 DO
                SET @choice2 := FLOOR(1 + RAND() * 4);
            END WHILE;
            
            -- 确保有序排列 (政治->地理->生物->化学)
            IF @choice1 > @choice2 THEN
                SET @temp := @choice1;
                SET @choice1 := @choice2;
                SET @choice2 := @temp;
            END IF;
            
            CASE @choice1
                WHEN 1 THEN SET @subject1 := '政治';
                WHEN 2 THEN SET @subject1 := '地理';
                WHEN 3 THEN SET @subject1 := '生物';
                WHEN 4 THEN SET @subject1 := '化学';
            END CASE;
            
            CASE @choice2
                WHEN 1 THEN SET @subject2 := '政治';
                WHEN 2 THEN SET @subject2 := '地理';
                WHEN 3 THEN SET @subject2 := '生物';
                WHEN 4 THEN SET @subject2 := '化学';
            END CASE;
            
            SET four_subject = CONCAT(@subject1, ',', @subject2);
            
            -- 3. 限制特定组合人数 (< 20人)
            -- 检查是否为 "物理"+"政治,地理" 组合
            IF two_subject = '物理' AND four_subject = '政治,地理' THEN
                IF phys_pol_geo_count >= 15 THEN
                    -- 重新生成四选二
                    SET @subject1 := '生物';
                    SET @subject2 := '化学';
                    SET four_subject = CONCAT(@subject1, ',', @subject2);
                ELSE
                    SET phys_pol_geo_count = phys_pol_geo_count + 1;
                END IF;
            END IF;
            
            -- 检查是否为 "历史"+"生物,化学" 组合
            IF two_subject = '历史' AND four_subject = '生物,化学' THEN
                IF hist_bio_chem_count >= 10 THEN
                    -- 重新生成四选二
                    SET @subject1 := '政治';
                    SET @subject1 := '地理';
                    SET four_subject = CONCAT(@subject1, ',', @subject2);
                ELSE
                    SET hist_bio_chem_count = hist_bio_chem_count + 1;
                END IF;
            END IF;
            
            -- 插入选课记录
            INSERT INTO student_course_choose (student_id, two_choose_one, four_choose_two)
            VALUES (current_student_id, two_subject, four_subject);
            
            -- 每100个学生输出一次进度
            IF i % 100 = 0 THEN
                SELECT CONCAT('已处理 ', i, ' 名学生，当前学生ID: ', current_student_id) AS progress;
            END IF;
        ELSE
            SELECT CONCAT('第 ', i, ' 个学生ID为空，跳过') AS warning;
        END IF;
        
        SET i = i + 1;
    END WHILE;
    
    SELECT CONCAT('数据插入完成，物理:历史 = ', physical_count, ':', history_count, '，总计 ', physical_count + history_count, ' 名学生') AS summary;
    
END $$

DELIMITER ;

-- 调用存储过程生成选课数据
CALL proc_generate_course_selection_data();

-- 显示选课数据统计
SELECT 
    two_choose_one,
    four_choose_two,
    COUNT(*) as student_count
FROM student_course_choose 
GROUP BY two_choose_one, four_choose_two
ORDER BY two_choose_one, four_choose_two;
