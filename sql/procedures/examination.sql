USE Database_Design;

DELIMITER //

-- 更新指定考试课目的排名
DROP PROCEDURE IF EXISTS UpdateExamRank //
CREATE PROCEDURE UpdateExamRank(
    IN i_exam_id VARCHAR(20),       -- '%' 可以全部考试排序
    IN i_course_id VARCHAR(20)      -- '%' 可以全部科目排序
)
BEGIN
    UPDATE exam_score es
    JOIN (
        SELECT 
            id,
            RANK() OVER ( -- 同分同名
                PARTITION BY exam_id, course_id 
                ORDER BY original_score DESC
            ) as calculated_rank
        FROM exam_score
        WHERE original_score IS NOT NULL
        AND exam_id LIKE i_exam_id
        AND course_id LIKE i_course_id
    ) ranked ON es.id = ranked.id
    SET es.course_rank = ranked.calculated_rank;
END //


-- 等级赋分计算
DROP PROCEDURE IF EXISTS CalculateConvertScore //
CREATE PROCEDURE CalculateConvertScore(
    IN input_exam_id VARCHAR(20),
    IN input_course_id VARCHAR(20)
)
BEGIN
    -- 声明变量
    DECLARE total_students INT DEFAULT 0;
    -- 预计算
    DECLARE rank_upper_A INT;
    DECLARE rank_upper_B INT;
    DECLARE rank_upper_C INT;
    DECLARE rank_upper_D INT;
    
    -- 获取该考试的总人数
    SELECT COUNT(*) INTO total_students
    FROM exam_score
    WHERE exam_id = input_exam_id 
        AND course_id = input_course_id
        AND original_score IS NOT NULL;
    
    -- 检查是否需要计算赋分
    IF EXISTS (SELECT 1 FROM course WHERE course_id = input_course_id AND is_score_convert != '是') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该课程不参与赋分';
    END IF;

    -- 预计算
    SET rank_upper_A = CEIL(total_students * 0.15);
    SET rank_upper_B = CEIL(total_students * (0.15+0.35));
    SET rank_upper_C = CEIL(total_students * (0.15+0.35+0.35));
    SET rank_upper_D = CEIL(total_students * (0.15+0.35+0.35+0.13));
    
    -- 计算并更新赋分成绩
    UPDATE exam_score 
    SET convert_score = CASE
        WHEN course_rank <= rank_upper_A THEN -- A等级 (前15%): 100~86分
            ROUND(100 - ((course_rank * 100.00 / total_students) / 15) * 14, 2)
        WHEN course_rank <= rank_upper_B THEN
            ROUND(85 - (((course_rank * 100.00 / total_students) - 15) / 35) * 14, 2)
        WHEN course_rank <= rank_upper_C THEN
            ROUND(70 - (((course_rank * 100.00 / total_students) - 50) / 35) * 14, 2)
        WHEN course_rank <= rank_upper_D THEN
            ROUND(55 - (((course_rank * 100.00 / total_students) - 85) / 13) * 14, 2)
        ELSE
            ROUND(40 - (((course_rank * 100.00 / total_students) - 98) / 2) * 10, 2)
    END
    WHERE exam_id = input_exam_id 
        AND course_id = input_course_id
        AND original_score IS NOT NULL;
    
    -- 确保赋分成绩在合理范围内
    UPDATE exam_score 
    SET convert_score = GREATEST(30, LEAST(100, convert_score))
    WHERE exam_id = input_exam_id 
        AND course_id = input_course_id
        AND original_score IS NOT NULL;
END //

DELIMITER ;

-- 示例
-- CALL UpdateExamRank('E2026011517423001', 'C008');
-- CALL UpdateExamRank('E2026011517423001', '%');
-- CALL CalculateConvertScore('E2026011517423001', 'C008');
-- 查看效果
-- select *
-- from exam_score
-- where exam_id = 'E2026011517423001'
-- and course_id = 'C008'
-- order by original_score desc;
