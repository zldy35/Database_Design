DELIMITER //

-- 更新所有考试和课程的排名
CREATE PROCEDURE UpdateExamRank()
BEGIN
    UPDATE course_score cs
    JOIN (
        SELECT 
            id,
            RANK() OVER ( -- 同分同名
                PARTITION BY exam_id, course_id 
                ORDER BY original_score DESC
            ) as calculated_rank
        FROM exam_score
        WHERE original_score IS NOT NULL
    ) ranked ON cs.id = ranked.id
    SET cs.exam_rank = ranked.calculated_rank;
END //


-- 等级赋分计算
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
    SELECT valid_exam_num INTO total_students
    FROM exam
    WHERE exam_id = input_exam_id;
    
    -- 检查是否需要计算赋分
    IF EXISTS (SELECT 1 FROM course WHERE course_id = input_course_id AND is_score_convert != '是') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '该课程不参与赋分';
    END IF;

    -- 预计算
    SET rank_upper_A = CEIL(total_students * 0.15);
    SET rank_upper_B = CEIL(total_students * (0.15+0.35));
    SET rank_upper_C = CEIL(total_students * (0.15+0.35+0.35));
    SET rank_upper_D = CELIL(total_students * (0.15+0.35+0.35+0.13));
    
    -- 计算并更新赋分成绩
    UPDATE exam_score 
    SET convert_score = CASE
        WHEN exam_rank <= rank_bound_A THEN -- A等级 (前15%): 100~86分
            ROUND(100 - ((exam_rank * 100.00 / total_students) / 15) * 14, 2)
        WHEN exam_rank <= rank_bound_B THEN
            ROUND(85 - (((exam_rank * 100.00 / total_students) - 15) / 35) * 14, 2)
        WHEN exam_rank <= rank_bound_C THEN
            ROUND(70 - (((exam_rank * 100.00 / total_students) - 50) / 35) * 14, 2)
        WHEN exam_rank <= rank_bound_D THEN
            ROUND(55 - (((exam_rank * 100.00 / total_students) - 85) / 13) * 14, 2)
        ELSE
            ROUND(40 - (((exam_rank * 100.00 / total_students) - 98) / 2) * 10, 2)
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
