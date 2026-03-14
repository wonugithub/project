from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import google.generativeai as genai
import json

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

genai.configure(api_key="api_key")
model = genai.GenerativeModel('gemini-2.5-flash', generation_config={"response_mime_type": "application/json"})

class IngredientRequest(BaseModel):
    ingredients: list[str]

@app.post("/api/recipes")
async def generate_recipe(request: IngredientRequest):
    # 프롬프트 엔지니어링을 통해 디테일한 조리법을 강제합니다.
    prompt = f"""
    사용자가 가진 식재료: {request.ingredients}
    이 재료들을 주로 활용할 수 있는 건강한 식단 레시피를 3개에서 5개 제안해.
    
    [핵심 지시사항]
    'instructions(조리법)' 배열의 각 단계는 요리 초보자도 완벽하게 따라 할 수 있도록 다음 요소를 반드시 포함하여 아주 상세한 행동 지침으로 작성할 것:
    1. 재료 손질 크기 및 방법 (예: 0.5cm 두께로 채썰기, 핏물 제거하기)
    2. 정확한 불의 세기 (강불, 중불, 약불)
    3. 구체적인 조리 시간 및 상태 변화 (예: 중불에서 3분간 볶아 양파가 반투명해질 때까지)
    4. 요리의 디테일을 살리는 셰프의 팁 (예: 이 단계에서 타지 않게 주의하세요)
    
    반드시 아래의 JSON 배열(Array) 형식으로만 응답할 것.
    [
      {{
        "recipe_name": "요리 이름", 
        "used_ingredients": ["사용된 메인 재료"], 
        "missing_essential_ingredients": ["부족한 필수 부재료"], 
        "recommended_additions": ["추천 추가 재료"], 
        "macros_estimate": {{"protein": "30g", "carbs": "40g", "fat": "10g"}}, 
        "instructions": [
            "1. [재료 준비] 돼지고기는 키친타월로 핏물을 제거하고 사방 2cm 크기로 깍둑썰기 합니다. 두부는 부서지지 않게 1.5cm 두께로 큼직하게 썰어주세요.", 
            "2. [조리 시작] 중불로 달군 냄비에 식용유 1큰술을 두르고 돼지고기를 넣어 겉면이 옅은 갈색이 될 때까지 약 3~4분간 충분히 볶아 잡내를 날려줍니다."
        ]
      }}
    ]
    """
    response = model.generate_content(prompt)
    return json.loads(response.text)