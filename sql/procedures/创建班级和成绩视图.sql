-- 用存储过程为每个班级生成视图
DELIMITER $$
DROP PROCEDURE IF EXISTS proc_create_class_view; 
CREATE PROCEDURE proc_create_class_view()
BEGIN
    DECLARE v_class_id VARCHAR(20);
    DECLARE v_done INT DEFAULT 0;
    
    -- 用游标查询所有班级的班级ID
    DECLARE cur_class CURSOR FOR SELECT class_id FROM class;
    
    -- 游标结束处理
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN cur_class;
    
    -- 循环遍历所有班级
    class_loop: LOOP
        FETCH cur_class INTO v_class_id;
        IF v_done = 1 THEN
            LEAVE class_loop;
        END IF;
        
        -- 生成视图名称 如：class_C101
        SET @view_name = CONCAT('class_', v_class_id);
        SET @create_sql = CONCAT(
            'CREATE VIEW ', @view_name, ' AS ',
            'SELECT ROW_NUMBER() OVER() AS id, student_id, student_name, gender, class_id ',
            'FROM student WHERE class_id = ''', v_class_id, ''';'
        );
        
        SET @drop_sql = CONCAT('DROP VIEW IF EXISTS ', @view_name, ';');
        PREPARE drop_stmt FROM @drop_sql;
        EXECUTE drop_stmt;
        DEALLOCATE PREPARE drop_stmt;
        
        -- 执行创建视图SQL
        PREPARE create_stmt FROM @create_sql;
        EXECUTE create_stmt;
        DEALLOCATE PREPARE create_stmt;
        
    END LOOP class_loop;
    
    CLOSE cur_class;
    
    SELECT '所有班级学生视图创建完成！' AS 执行结果;
END $$
DELIMITER ;


CALL proc_create_class_view();

# 用存储过程生成每次考试的成绩视图
DELIMITER $$
DROP PROCEDURE IF EXISTS proc_create_exam_view;
CREATE PROCEDURE proc_create_exam_view()
BEGIN
    -- 定义变量：接收考试编号、游标结束标识
    DECLARE v_exam_id VARCHAR(20);
    DECLARE v_exam_name VARCHAR(100);
    DECLARE v_done INT DEFAULT 0;
    
    -- 用游标查询exam表中所有考试编号
    DECLARE cur_exam CURSOR FOR SELECT exam_id, exam_name FROM exam;
    -- 游标结束处理
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    -- 循环遍历考试
    OPEN cur_exam;
    exam_loop: LOOP
        FETCH cur_exam INTO v_exam_id, v_exam_name;
        IF v_done = 1 THEN
            LEAVE exam_loop;
        END IF;
        
        -- 生成视图名称，如exam_高二年级第一次月考
        SET @view_name = CONCAT('exam_', v_exam_name);
        
        -- 创建视图SQL
        SET @create_sql = CONCAT(
            'CREATE VIEW ', @view_name, ' AS ',
            'SELECT ROW_NUMBER() OVER(ORDER BY total_score DESC, yw_score DESC, sx_score DESC, yy_score DESC, zk_sum DESC) AS rank_id,',
            'student_id, total_score ',
            'FROM (',
                'SELECT student_id,',
                'SUM(IF(convert_score IS NOT NULL, convert_score, original_score)) AS total_score,',
                'MAX(IF(course_id="C001", original_score, 0)) AS yw_score,',
                'MAX(IF(course_id="C002", original_score, 0)) AS sx_score,',
                'MAX(IF(course_id="C003", original_score, 0)) AS yy_score,',
                'SUM(IF(course_id NOT IN("C001","C002","C003"),IF(convert_score IS NOT NULL, convert_score, original_score),0)) AS zk_sum ',
                'FROM exam_score WHERE exam_id = ''', v_exam_id, ''' ',
                'GROUP BY student_id',
            ') AS total ',
            'ORDER BY total_score DESC, yw_score DESC, sx_score DESC, yy_score DESC, zk_sum DESC;'
        );
        
        
        SET @drop_sql = CONCAT('DROP VIEW IF EXISTS ', @view_name, ';');
        PREPARE drop_stmt FROM @drop_sql;
        EXECUTE drop_stmt;
        DEALLOCATE PREPARE drop_stmt;
        
        -- 执行创建考试成绩视图sql
        PREPARE create_stmt FROM @create_sql;
        EXECUTE create_stmt;
        DEALLOCATE PREPARE create_stmt;
        
    END LOOP exam_loop;
    
    CLOSE cur_exam;
    SELECT '所有考试的独立成绩视图创建完成！' AS 执行结果;
END $$
DELIMITER ;

-- 调用存储过程，自动生成所有考试的成绩视图
CALL proc_create_exam_view();