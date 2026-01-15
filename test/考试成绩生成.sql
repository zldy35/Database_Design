USE Database_Design;

DELIMITER //

-- 为高二学生生成考试成绩
DROP PROCEDURE IF EXISTS GenerateGrade2ExamScore //
CREATE PROCEDURE GenerateGrade2ExamScore(
    IN p_exam_name VARCHAR(100)
)
BEGIN
    DECLARE v_exam_id VARCHAR(20);
    DECLARE v_student_id VARCHAR(20);
    DECLARE v_class_id VARCHAR(20);
    DECLARE v_subject_combination VARCHAR(100);
    DECLARE v_two_choose_one VARCHAR(10);
    DECLARE v_four_choose_two VARCHAR(50);
    DECLARE v_course_id VARCHAR(20);
    DECLARE v_course_name VARCHAR(50);
    DECLARE v_original_score DECIMAL(5,2);
    DECLARE v_counter INT DEFAULT 0;
    DECLARE v_total_students INT DEFAULT 0;
    DECLARE v_done INT DEFAULT FALSE;
    DECLARE v_records INT DEFAULT 0;
    
    -- 定义课程ID映射变量
    DECLARE v_course_count INT DEFAULT 0;
    DECLARE v_current_course VARCHAR(50);
    DECLARE v_course_iter INT DEFAULT 0;
    DECLARE v_course_array TEXT;
    
    -- 游标声明必须在变量声明之后
    DECLARE student_cursor CURSOR FOR
        SELECT s.student_id, s.class_id, c.subject_combination
        FROM student s
        JOIN class c ON s.class_id = c.class_id
        WHERE s.grade = 2;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    -- 生成考试ID
    SET v_exam_id = CONCAT('E', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'), LPAD(1, 2, '0'));
    
    -- 检查是否已存在相同名称的考试
    IF EXISTS(SELECT 1 FROM exam WHERE exam_name = p_exam_name) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '考试名称已存在';
    END IF;
    
    -- 插入考试信息
    INSERT INTO exam (exam_id, exam_name, exam_time, valid_exam_num, remark)
    VALUES (v_exam_id, p_exam_name, NOW(), 0, CONCAT('高二年级', '-', p_exam_name));
    
    -- 获取高二学生总数
    SELECT COUNT(*) INTO v_total_students
    FROM student s
    JOIN class c ON s.class_id = c.class_id
    WHERE s.grade = 2;
    
    -- 打开游标
    OPEN student_cursor;
    
    student_loop: LOOP
        FETCH student_cursor INTO v_student_id, v_class_id, v_subject_combination;
        
        IF v_done THEN
            LEAVE student_loop;
        END IF;
        
        -- 获取学生的选课信息
        SELECT two_choose_one, four_choose_two
        INTO v_two_choose_one, v_four_choose_two
        FROM student_course_choose
        WHERE student_id = v_student_id;
        
        -- 为语数英三门必考科目生成成绩
        CALL InsertExamScore(v_exam_id, v_student_id, 'C001', ROUND(60 + RAND() * 40, 0)); -- 语文
        CALL InsertExamScore(v_exam_id, v_student_id, 'C002', ROUND(60 + RAND() * 40, 0)); -- 数学
        CALL InsertExamScore(v_exam_id, v_student_id, 'C003', ROUND(60 + RAND() * 40, 0)); -- 英语
        
        -- 根据two_choose_one生成对应选考科目成绩
        IF v_two_choose_one = '物理' THEN
            CALL InsertExamScore(v_exam_id, v_student_id, 'C004', ROUND(60 + RAND() * 40, 0)); -- 物理
        ELSEIF v_two_choose_one = '历史' THEN
            CALL InsertExamScore(v_exam_id, v_student_id, 'C005', ROUND(60 + RAND() * 40, 0)); -- 历史
        END IF;
        
        -- 根据four_choose_two生成对应选考科目成绩
        IF v_four_choose_two LIKE '%政治%' THEN
            CALL InsertExamScore(v_exam_id, v_student_id, 'C006', ROUND(60 + RAND() * 40, 0)); -- 政治
        END IF;
        IF v_four_choose_two LIKE '%地理%' THEN
            CALL InsertExamScore(v_exam_id, v_student_id, 'C007', ROUND(60 + RAND() * 40, 0)); -- 地理
        END IF;
        IF v_four_choose_two LIKE '%生物%' THEN
            CALL InsertExamScore(v_exam_id, v_student_id, 'C008', ROUND(60 + RAND() * 40, 0)); -- 生物
        END IF;
        IF v_four_choose_two LIKE '%化学%' THEN
            CALL InsertExamScore(v_exam_id, v_student_id, 'C009', ROUND(60 + RAND() * 40, 0)); -- 化学
        END IF;
        
        SET v_counter = v_counter + 1;
        
    END LOOP;
    
    CLOSE student_cursor;
    
    -- 更新考试的参考人数
    UPDATE exam
    SET valid_exam_num = v_total_students
    WHERE exam_id = v_exam_id;

    SELECT count(*) INTO v_records
    FROM exam_score;
    
    SELECT CONCAT('考试生成完成: ', p_exam_name, ', 共为 ', v_total_students, ' 名高二学生生成了成绩，共 ', v_records, ' 条成绩记录') AS Result;
    
END //


-- 插入考试成绩的辅助存储过程
DROP PROCEDURE IF EXISTS InsertExamScore //
CREATE PROCEDURE InsertExamScore(
    IN p_exam_id VARCHAR(20),
    IN p_student_id VARCHAR(20),
    IN p_course_id VARCHAR(20),
    IN p_original_score DECIMAL(5,2)
)
BEGIN
    -- 检查是否已存在该学生该科目的成绩记录
    IF NOT EXISTS(
        SELECT 1 
        FROM exam_score 
        WHERE exam_id = p_exam_id AND student_id = p_student_id AND course_id = p_course_id
    ) THEN
        INSERT INTO exam_score (exam_id, student_id, course_id, original_score)
        VALUES (p_exam_id, p_student_id, p_course_id, p_original_score);
    END IF;
END //

DELIMITER ;

-- 调用示例
-- CALL GenerateGrade2ExamScore('高二年级第一次月考');
