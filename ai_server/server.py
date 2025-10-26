# server.py

import os
from werkzeug.utils import secure_filename
from datetime import datetime
import sqlite3
from werkzeug.security import generate_password_hash, check_password_hash
from flask import Flask, request, jsonify
from PIL import Image
import numpy as np

from predict import load_model, preprocess_image, predict_cloth_type
from database import init_db, DATABASE_NAME

app = Flask(__name__)

init_db()
load_model()

# --- ▼▼▼ [추가] 이미지 업로드를 위한 설정 ▼▼▼ ---
UPLOAD_FOLDER = 'uploads' # 이미지를 저장할 폴더 이름
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'} # 허용할 확장자

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# 폴더가 없으면 생성
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS
# --- ▲▲▲ [추가] 이미지 업로드를 위한 설정 ▲▲▲ ---

@app.route('/')
def home():
    return "AI 모델 서버가 작동 중입니다."

@app.route('/predict', methods=['POST'])
def handle_prediction():
    if 'image' not in request.files:
        return jsonify({'error': '이미지 파일이 없습니다.'}), 400
    image_file = request.files['image']
    try:
        processed_image = preprocess_image(image_file.stream)
        prediction_result = predict_cloth_type(processed_image)
        return jsonify(prediction_result)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    name = data.get('name')
    gender = data.get('gender')
    birth_date = data.get('birth_date')
    phone_number = data.get('phone_number')

    if not email or not password or not name:
        return jsonify({'message': '필수 정보를 모두 입력해주세요.'}), 400

    conn = sqlite3.connect(DATABASE_NAME)
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
    if cursor.fetchone():
        conn.close()
        return jsonify({'message': '이미 사용 중인 이메일입니다.'}), 409

    password_hash = generate_password_hash(password)
    try:
        cursor.execute('''
            INSERT INTO users (email, password_hash, name, gender, birth_date, phone_number)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (email, password_hash, name, gender, birth_date, phone_number))
        conn.commit()
        message = '회원가입이 완료되었습니다.'
        status_code = 200
    except sqlite3.Error as e:
        conn.rollback()
        message = f'데이터베이스 오류: {e}'
        status_code = 500
    finally:
        conn.close()
    return jsonify({'message': message}), status_code

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({"message": "이메일과 비밀번호를 모두 입력해주세요."}), 400

    conn = sqlite3.connect(DATABASE_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
    user = cursor.fetchone()
    conn.close()

    if user and check_password_hash(user['password_hash'], password):
        return jsonify({"message": "로그인 성공!", "userName": user['name']}), 200
    else:
        return jsonify({"message": "이메일 또는 비밀번호가 잘못되었습니다."}), 401

# --- ▼▼▼ [수정] 옷 추가 API (user_id 찾기, 오류 처리 추가) ▼▼▼ ---
@app.route('/clothes', methods=['POST'])
def add_cloth():
    data = request.get_json()
    email = data.get('email')
    name = data.get('name')
    clothingImg = data.get('clothingImg')

    if not email or not name:
        return jsonify({"message": "이메일과 옷 이름은 필수입니다."}), 400
    if not clothingImg:
         return jsonify({"message": "이미지 경로가 없습니다."}), 400

    conn = None # finally 에서 사용하기 위해 try 밖에 선언
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        conn.row_factory = sqlite3.Row # 결과를 dictionary처럼 사용하기 위해 추가
        cursor = conn.cursor()

        # 1. 이메일로 user_id를 찾습니다.
        cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
        user_row = cursor.fetchone()

        if user_row is None:
             # conn.close() 는 finally 에서 처리하므로 여기서 닫지 않음
             return jsonify({"message": "사용자를 찾을 수 없습니다."}), 404
        user_id = user_row['id']

        # 2. 찾은 user_id와 함께 옷 정보를 저장합니다.
        cursor.execute('''
            INSERT INTO clothes (user_id, name, subCategory, articleType, color, clothingImg, memo)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, name, data.get('subCategory'), data.get('articleType'), data.get('color'), clothingImg, data.get('memo')))
        conn.commit()
        return jsonify({"message": "옷이 성공적으로 추가되었습니다."}), 201

    except sqlite3.Error as e: # 데이터베이스 관련 오류 처리
        if conn:
            conn.rollback() # 오류 발생 시 롤백
        print(f"Database error in add_cloth: {e}")
        return jsonify({"message": f"데이터베이스 오류: {e}"}), 500
    except Exception as e: # 그 외 모든 예외 처리
        print(f"An error occurred in add_cloth: {e}")
        return jsonify({"message": f"서버 내부 오류: {e}"}), 500
    finally: # 성공하든 실패하든 항상 실행
        if conn:
            conn.close() # 데이터베이스 연결 종료
# --- ▲▲▲ [수정] 옷 추가 API (user_id 찾기, 오류 처리 추가) ▲▲▲ ---


@app.route('/clothes/<email>', methods=['GET'])
def get_clothes(email):
    if not email:
        return jsonify({"message": "이메일 정보가 필요합니다."}), 400

    conn = sqlite3.connect(DATABASE_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
    user_row = cursor.fetchone()

    if user_row is None:
        conn.close()
        return jsonify({"message": "사용자를 찾을 수 없습니다."}), 404

    user_id = user_row['id']

    cursor.execute("SELECT * FROM clothes WHERE user_id = ?", (user_id,))
    clothes_rows = cursor.fetchall()
    conn.close()
    
    clothes_list = [dict(row) for row in clothes_rows]
    return jsonify(clothes_list)

# --- ▼▼▼ [추가됨] 옷 삭제 API 엔드포인트 ▼▼▼ ---
@app.route('/clothes/<int:cloth_id>', methods=['DELETE'])
def delete_cloth(cloth_id):
    conn = None
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        cursor = conn.cursor()

        # 삭제하려는 옷이 존재하는지 확인
        cursor.execute("SELECT id FROM clothes WHERE id = ?", (cloth_id,))
        cloth_exists = cursor.fetchone()

        if not cloth_exists:
            conn.close()
            return jsonify({"message": "삭제할 옷을 찾을 수 없습니다."}), 404

        # 옷 삭제 실행
        cursor.execute("DELETE FROM clothes WHERE id = ?", (cloth_id,))
        conn.commit()

        # 삭제된 행의 수가 0보다 크면 성공
        if conn.total_changes > 0:
            return jsonify({"message": "옷이 성공적으로 삭제되었습니다."}), 200
        else:
            # 동시성 문제 등으로 삭제되지 않은 경우
            return jsonify({"message": "옷 삭제에 실패했습니다."}), 500

    except sqlite3.Error as e:
        if conn:
            conn.rollback()  # 오류 발생 시 롤백
        print(f"An error occurred in DELETE /clothes/<cloth_id>: {e}")
        return jsonify({"message": f"데이터베이스 오류: {e}"}), 500
    except Exception as e:
        print(f"An error occurred in DELETE /clothes/<cloth_id>: {e}")
        return jsonify({"message": f"서버 내부 오류: {e}"}), 500
    finally:
        if conn:
            conn.close()
# --- ▲▲▲ [추가됨] 옷 삭제 API 엔드포인트 ▲▲▲ ---

# --- ▼▼▼ [추가] 일정 삭제 API 엔드포인트 ▼▼▼ ---
@app.route('/schedule/<int:schedule_id>', methods=['DELETE'])
def delete_schedule(schedule_id):
    conn = None
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        cursor = conn.cursor()

        # 삭제하려는 일정이 존재하는지 먼저 확인 (선택 사항이지만 권장)
        cursor.execute("SELECT schedule_id FROM schedule WHERE schedule_id = ?", (schedule_id,))
        schedule_exists = cursor.fetchone()

        if not schedule_exists:
            return jsonify({"message": "삭제할 일정을 찾을 수 없습니다."}), 404

        # 일정 삭제 실행
        cursor.execute("DELETE FROM schedule WHERE schedule_id = ?", (schedule_id,))
        conn.commit()

        # 삭제된 행의 수가 0보다 크면 성공
        if conn.total_changes > 0:
            return jsonify({"message": "일정이 성공적으로 삭제되었습니다."}), 200
        else:
            # 혹시 모를 동시성 문제 등으로 삭제되지 않은 경우
            return jsonify({"message": "일정 삭제에 실패했습니다."}), 500

    except sqlite3.Error as e:
        if conn:
            conn.rollback() # 오류 발생 시 롤백
        print(f"An error occurred in DELETE /schedule/<schedule_id>: {e}")
        return jsonify({"message": f"데이터베이스 오류: {e}"}), 500
    except Exception as e:
        print(f"An error occurred in DELETE /schedule/<schedule_id>: {e}")
        return jsonify({"message": f"서버 내부 오류: {e}"}), 500
    finally:
        if conn:
            conn.close()
# --- ▲▲▲ [추가] 일정 삭제 API 엔드포인트 ▲▲▲ ---

# --- ▼▼▼ [수정] TPO 데이터 저장 로직 추가 ▼▼▼ ---
@app.route('/schedule', methods=['POST'])
def add_schedule():
    conn = None
    try:
        data = request.get_json()
        if not data:
            return jsonify({"message": "요청 본문이 비어있거나 JSON 형식이 아닙니다."}), 400

        email = data.get('email')
        title = data.get('title')

        if not email or not title:
            return jsonify({"message": "이메일과 일정 제목은 필수입니다."}), 400

        conn = sqlite3.connect(DATABASE_NAME)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
        user_row = cursor.fetchone()

        if user_row is None:
            return jsonify({"message": "사용자를 찾을 수 없습니다."}), 404
            
        user_id = user_row['id']
        
        cursor.execute('''
            INSERT INTO schedule (user_id, title, start_date, end_date, start_time, end_time, location_name, location_address, explanation, participants, recurrence_rule, alarm_unit, alarm_value, tpo1, tpo2)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            user_id, 
            title, 
            data.get('startDate'), 
            data.get('endDate'), 
            data.get('startTime'),
            data.get('endTime'),
            data.get('locationName'),
            data.get('locationAddress'),
            data.get('explanation'),
            data.get('participants'),
            data.get('recurrenceRule'),
            data.get('alarmUnit'),
            data.get('alarmValue'),
            data.get('tpo1'), # TPO1 데이터 추가
            data.get('tpo2')  # TPO2 데이터 추가
        ))
        conn.commit()
        
        return jsonify({"message": "일정이 성공적으로 추가되었습니다."}), 201

    except Exception as e:
        print(f"An error occurred in /schedule: {e}") 
        return jsonify({"message": f"서버 내부 오류가 발생했습니다: {e}"}), 500
    
    finally:
        if conn:
            conn.close()
# --- ▲▲▲ [수정] TPO 데이터 저장 로직 추가 ▲▲▲ ---

# --- ▼▼▼ [수정] TPO 데이터 조회 로직 추가 ▼▼▼ ---
@app.route('/schedule/<email>', methods=['GET'])
def get_schedules(email):
    if not email:
        return jsonify({"message": "이메일 정보가 필요합니다."}), 400

    conn = None
    try:
        conn = sqlite3.connect(DATABASE_NAME)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
        user_row = cursor.fetchone()

        if user_row is None:
            return jsonify({"message": "사용자를 찾을 수 없습니다."}), 404

        user_id = user_row['id']

        cursor.execute("SELECT * FROM schedule WHERE user_id = ?", (user_id,))
        schedule_rows = cursor.fetchall()
        
        schedule_list = [
            {
                "schedule_id": row["schedule_id"],
                "user_id": row["user_id"],
                "title": row["title"],
                "startDate": row["start_date"],
                "endDate": row["end_date"],
                "startTime": row["start_time"],
                "endTime": row["end_time"],
                "location": row["location_name"],
                "locationAddress": row["location_address"],
                "explanation": row["explanation"],
                "participants": row["participants"],
                "recurrenceRule": row["recurrence_rule"],
                "alarmUnit": row["alarm_unit"],
                "alarmValue": row["alarm_value"],
                "tpo1": row["tpo1"], # TPO1 데이터 추가
                "tpo2": row["tpo2"], # TPO2 데이터 추가
            }
            for row in schedule_rows
        ]
        
        return jsonify(schedule_list)

    except Exception as e:
        print(f"An error occurred in /schedule/<email>: {e}")   
        return jsonify({"message": f"서버 내부 오류: {e}"}), 500
    finally:
        if conn:
            conn.close()
# --- ▲▲▲ [수정] TPO 데이터 조회 로직 추가 ▲▲▲ ---

# --- ▼▼▼ [추가] 이미지 업로드 API 엔드포인트 ▼▼▼ ---
@app.route('/upload_image', methods=['POST'])
def upload_image():
    if 'image' not in request.files:
        return jsonify({'error': '이미지 파일이 없습니다.'}), 400
    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': '선택된 파일이 없습니다.'}), 400
    if file and allowed_file(file.filename):
        # 파일 이름을 안전하게 만들고 저장 경로 생성
        filename = secure_filename(f"{datetime.now().strftime('%Y%m%d%H%M%S')}_{file.filename}")
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        # 클라이언트에게 돌려줄 이미지 접근 경로 (예: 상대 경로)
        # 실제 운영 시에는 전체 URL (http://서버IP:포트/uploads/파일명)을 반환하는 것이 좋음
        image_url = f"{UPLOAD_FOLDER}/{filename}" 
        
        return jsonify({'message': '이미지 업로드 성공', 'image_url': image_url}), 201
    else:
        return jsonify({'error': '허용되지 않는 파일 형식입니다.'}), 400
# --- ▲▲▲ [추가] 이미지 업로드 API 엔드포인트 ▲▲▲ ---

# --- ▼▼▼ [추가] 업로드된 이미지 파일을 서빙하는 엔드포인트 ▼▼▼ ---
from flask import send_from_directory

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    # UPLOAD_FOLDER에서 파일을 찾아 반환
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)
# --- ▲▲▲ [추가] 업로드된 이미지 파일을 서빙하는 엔드포인트 ▲▲▲ ---

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
