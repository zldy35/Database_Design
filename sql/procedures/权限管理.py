import pymysql

# ========== 数据库连接配置 ==========
DB_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "user": "root",
    "password": "808040597",
    "database": "database_design",
    "charset": "utf8mb4",
    "cursorclass": pymysql.cursors.DictCursor  # 返回字典格式，直观取值
}

def get_db_conn():
    """获取数据库连接"""
    conn = pymysql.connect(**DB_CONFIG)
    return conn

# ========== 获取用户角色+权限关联信息 ==========
def get_user_role_and_info(operate_account: str) -> dict:
    """根据操作人账号，查询【角色+角色专属信息】"""
    conn = get_db_conn()
    cursor = conn.cursor()
    res = {
        "role_name": None,
        "class_id": None,      # 班主任带的班级ID
        "course_ids": []       # 科任老师授课课程ID列表
    }
    try:
        # 查询当前账号的角色
        sql_role = f"""
            SELECT r.role_name 
            FROM account_role ar
            JOIN role r ON ar.role_id = r.role_id
            WHERE ar.account_id = '{operate_account}'
            ORDER BY FIELD(r.role_name,'校长','教务主任','班主任','科任老师','学生') ASC
            LIMIT 1;
        """
        cursor.execute(sql_role)
        role_data = cursor.fetchone()
        if role_data:
            res["role_name"] = role_data["role_name"]

        # 班主任 → 获取所带班级ID
        if res["role_name"] == "班主任":
            sql_class = f"SELECT class_id FROM class WHERE head_teacher_id = '{operate_account}';"
            cursor.execute(sql_class)
            class_data = cursor.fetchone()
            if class_data:
                res["class_id"] = class_data["class_id"]

        # 科任老师 → 获取授课课程ID列表
        if res["role_name"] in ["科任老师", "班主任"]:
            sql_course_name = f"SELECT course FROM staff WHERE staff_id = '{operate_account}';"
            cursor.execute(sql_course_name)
            course_name_data = cursor.fetchone()
            
            # 非空校验：字段有值 且 去除空格后不为空
            if course_name_data and course_name_data["course"] and len(course_name_data["course"].strip()) > 0:
                course_names = [name.strip() for name in course_name_data["course"].split(",")]
                # 过滤空值，防止分割后出现空字符串
                course_names = [cn for cn in course_names if cn]
                
                if course_names:
                    # ============ 核心适配：老师只教单门课程 专属处理 ============
                    if len(course_names) == 1:
                        # 单课程：用 = 匹配，彻底规避元组语法BUG，效率更高
                        sql_course_id = f"SELECT course_id FROM course WHERE course_name = '{course_names[0]}';"
                    else:
                        # 多课程：用 IN 匹配，兼容多课程场景
                        sql_course_id = f"SELECT course_id FROM course WHERE course_name IN {tuple(course_names)};"
                    
                    cursor.execute(sql_course_id)
                    course_id_data = cursor.fetchall()
                    # 提取课程ID列表
                    res["course_ids"] = [item["course_id"] for item in course_id_data]

        return res
    finally:
        cursor.close()
        conn.close()

# ========== 查询某人成绩接口 ==========
def query_score(operate_account: str, target_student_id: str, target_course_id: str) -> dict:
    """
    判断是否有查询【指定学生】的【指定课程】成绩的权限
    input：操作人ID + 要查的学生学号 + 要查的课程ID
    """
    # ===== 步骤1：前置权限校验【唯一核心工作】 =====
    user_info = get_user_role_and_info(operate_account)
    role_name = user_info["role_name"]
    
    if not role_name:
        return {"code": 400, "msg": "权限异常：该账号未配置任何角色", "data": None}
    
    has_permission = False  # 权限开关，默认无权限

    # 学生：只能查自己的成绩 → 操作人ID == 目标学生ID
    if role_name == "学生":
        if operate_account == target_student_id:
            has_permission = True

    # 班主任：只能查自己班内的学生成绩
    elif role_name == "班主任":
        # 查目标学生的班级ID
        sql_student_class = f"SELECT class_id FROM student WHERE student_id = '{target_student_id}';"
        conn = get_db_conn()
        cursor = conn.cursor()
        cursor.execute(sql_student_class)
        student_class = cursor.fetchone()
        cursor.close()
        conn.close()
        # 校验：目标学生的班级 等于 班主任带的班级
        if student_class and student_class["class_id"] == user_info["class_id"]:
            has_permission = True

    # 科任老师：只能查所授课程学生的成绩
    elif role_name == "科任老师":
        if target_course_id in user_info["course_ids"]:
            has_permission = True

    # 教务主任/校长：无限制，直接放行
    elif role_name in ["教务主任", "校长"]:
        has_permission = True

    # 权限不通过 → 直接返回错误
    if not has_permission:
        return {"code": 403, "msg": f"你无权查询[{target_student_id}]的[{target_course_id}]课程成绩", "data": None}

    # ===== 权限通过，返回查询 =====
    conn = get_db_conn()
    cursor = conn.cursor()
    try:
        sql = f"""
            SELECT sc.exam_id, e.exam_name, c.course_name, sc.original_score, sc.convert_score, sc.course_rank
            FROM exam_score sc
            LEFT JOIN exam e ON sc.exam_id = e.exam_id
            LEFT JOIN student s ON sc.student_id = s.student_id
            LEFT JOIN course c ON sc.course_id = c.course_id
            WHERE sc.student_id = '{target_student_id}' AND sc.course_id = '{target_course_id}';
        """
        cursor.execute(sql)
        score_data = cursor.fetchall()
        return {"code": 200, "msg": "查询成功", "data": score_data}
    except Exception as e:
        return {"code": 500, "msg": f"查询失败：{str(e)}", "data": None}
    finally:
        cursor.close()
        conn.close()

# ========== 修改某人成绩接口+日志写入 ==========
def update_score(operate_account: str, score_id: int, new_original_score: float) -> dict:
    """
    修改【指定成绩ID】的分数
    仅科任老师可修改、且只能修改自己授课课程的成绩，其他角色无权限
    input：操作人ID + 要修改的成绩ID + 新分数
    """
    # ===== 前置权限校验 =====
    user_info = get_user_role_and_info(operate_account)
    role_name = user_info["role_name"]
    teach_course_ids = user_info["course_ids"]

    # 只有科任老师和班主任能修改成绩
    print(teach_course_ids)
    if role_name not in ["科任老师", "班主任"] or not teach_course_ids:
        return {"code": 403, "msg": "权限拒绝：只有科任老师能修改成绩", "data": None}
    
    conn = get_db_conn()
    cursor = conn.cursor()
    try:
        # 先查要修改的成绩原始信息，
        sql_get_old_score = f"SELECT id, exam_id, student_id, course_id, original_score FROM exam_score WHERE id = {score_id};"
        cursor.execute(sql_get_old_score)
        old_score_data = cursor.fetchone()

        if not old_score_data:
            return {"code": 404, "msg": f"修改失败：成绩ID[{score_id}]不存在", "data": None}
        
        # 只能修改自己授课课程的成绩
        target_course_id = old_score_data["course_id"]
        if target_course_id not in teach_course_ids:
            return {"code": 403, "msg": f"权限拒绝：你无权修改[{target_course_id}]课程的成绩", "data": None}

        # ===== 权限判断通过：修改成绩并写入日志 =====
        sql_update = f"UPDATE exam_score SET original_score = {new_original_score} WHERE id = {score_id};"
        cursor.execute(sql_update)

        # 写入日志
        old_score = old_score_data["original_score"]
        if old_score != new_original_score:
            sql_insert_log = f"""
                INSERT INTO exam_score_log 
                (score_id, exam_id, student_id, course_id, old_original_score, new_original_score, operate_account)
                VALUES ({old_score_data['id']}, '{old_score_data['exam_id']}', '{old_score_data['student_id']}', 
                '{old_score_data['course_id']}', {old_score}, {new_original_score}, '{operate_account}');
            """
        cursor.execute(sql_insert_log)

        conn.commit()
        return {"code": 200, "msg": f"修改成功：成绩ID[{score_id}]分数从{old_score}修改为{new_original_score}", "data": None}

    except Exception as e:
        conn.rollback()
        return {"code": 500, "msg": f"修改失败：{str(e)}", "data": None}
    finally:
        cursor.close()
        conn.close()
        
        
# ========== 修改教职工信息接口（仅校长有该权限） ==========
def update_staff_info_api(operate_account: str, staff_id: str, **kwargs) -> dict:
    """
    校长专属修改教职工信息接口
    :param operate_account: 当前操作人账号(工号/学号)
    :param staff_id: 要修改的教职工工号（必填）
    :param kwargs: 要修改的职工字段 如：staff_name='xxx', gender='男/女', position='职称', course='授课课程', is_leave='是/否'
    :return: 统一返回格式
    """
    # 权限校验
    user_info = get_user_role_and_info(operate_account)
    role_name = user_info["role_name"]
    if role_name != "校长":
        return {"code": 403, "msg": "权限拒绝：该操作仅限校长执行！", "data": None}

    conn = get_db_conn()
    cursor = conn.cursor()
    try:
        # 校验要修改的职工是否存在
        sql_check = f"SELECT staff_id FROM staff WHERE staff_id = '{staff_id}';"
        cursor.execute(sql_check)
        if not cursor.fetchone():
            return {"code": 400, "msg": f"教职工工号[{staff_id}]不存在！", "data": None}
        if staff_id == 'T000001':
            return {"code": 400, "msg": f"不能修改校长职位！", "data": None}

        # 拼接修改的字段SQL
        update_list = []
        for key, val in kwargs.items():
            if key in ["position", "course", "is_leave"]:
                update_list.append(f"{key} = '{val}'")
        if not update_list:
            return {"code": 400, "msg": "未传入有效修改字段！", "data": None}

        # 执行修改
        sql_update = f"UPDATE staff SET {','.join(update_list)} WHERE staff_id = '{staff_id}';"
        cursor.execute(sql_update)
        sql_select = f"SELECT staff_name, position, course, is_leave FROM staff WHERE staff_id = '{staff_id}';"
        cursor.execute(sql_select)
        conn.commit()
        return {"code": 200, "msg": f"教职工[{staff_id}] 信息修改成功！", "data": cursor.fetchone()}

    except Exception as e:
        conn.rollback()
        return {"code": 500, "msg": f"修改失败：{str(e)}", "data": None}
    finally:
        cursor.close()
        conn.close()
  

# ========== 直观测试调用示例 ==========
if __name__ == "__main__":
    # 测试1：学生查自己的成绩 有权限
    # print("===== 学生S0000001查自己的语文(C001)成绩 =====")
    # print(query_score("S000001", "S000001", "C001"))

    # # 测试2：学生查别人的成绩 无权限
    # print("===== 学生S000001查S000002的数学(C002)成绩 =====")
    # print(query_score("S000001", "S000002", "C002"))

    # 测试3：科任老师修改自己授课课程的成绩 有权限
    print("===== 科任老师T000004修改成绩ID=1(语文) =====")
    print(update_score("T000004", 1, 98.5))

    # 测试4：校长尝试修改成绩 无权限
    print("===== 校长T000001修改成绩ID=1 =====")
    print(update_score("T000001", 1, 99.0))
    
    # 测试5：校长修改职工信息 有权限
    print("===== 校长T000001修改职工信息 =====")
    print(update_staff_info_api("T000001", "T000005", position="教务主任", course="NULL"))
    
    # 测试6：其他人修改职工信息 无权限
    print("===== 教师T000002修改职工信息 =====")
    print(update_staff_info_api("T000002", "T000002", is_leave="是"))  