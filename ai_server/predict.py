import tensorflow as tf
import numpy as np
from PIL import Image

# --- 설정 ---
MODEL_PATH = 'best_model.h5'

# ▼▼▼▼▼ 중요! 아래 두 목록을 Colab 출력 결과로 완전히 교체하세요 ▼▼▼▼▼
SUB_CATEGORY_CLASSES = [
    'Bottomwear', 'Shoes', 'Topwear'  # Colab에서 복사한 내용으로 붙여넣기
]
ARTICLE_TYPE_CLASSES = [
    'Blazers', 'Capris', 'Casual Shoes', 'Dresses', 'Flats', 'Flip Flops', 'Formal Shoes', 'Heels', 'Jackets', 'Jeans', 'Jeggings', 'Jumpsuit', 'Leggings', 'Rain Jacket', 'Sandals', 'Shirts', 'Shorts', 'Shrug', 'Skirts', 'Sports Sandals', 'Sports Shoes', 'Sweaters', 'Sweatshirts', 'Tops', 'Track Pants', 'Tracksuits', 'Trousers', 'Tshirts', 'Waistcoat'
]
# ▲▲▲▲▲ 중요! 위 두 목록을 Colab 출력 결과로 완전히 교체하세요 ▲▲▲▲▲


# --- 핵심 기능 (수정 없음) ---
model = None

def load_model():
    global model
    if model is None:
        print(f"* Loading Keras model from {MODEL_PATH}...")
        model = tf.keras.models.load_model(MODEL_PATH)
        print("* Model loaded.")

def preprocess_image(image_file_storage):
    img = Image.open(image_file_storage).convert('RGB')
    img = img.resize((224, 224))
    img_array = tf.keras.utils.img_to_array(img)
    img_array /= 255.0
    img_array = np.expand_dims(img_array, axis=0)
    return img_array

def predict_cloth_type(image_array):
    predictions = model.predict(image_array)
    
    sub_category_index = np.argmax(predictions[0])
    article_type_index = np.argmax(predictions[1])
    
    sub_category_result = SUB_CATEGORY_CLASSES[sub_category_index]
    article_type_result = ARTICLE_TYPE_CLASSES[article_type_index]
    
    return {
        'subCategory': sub_category_result,
        'articleType': article_type_result
    }