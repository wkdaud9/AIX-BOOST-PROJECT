# 공지사항 API 사용 가이드

## 📌 엔드포인트 목록

### 1. 공지사항 크롤링 및 저장
```
POST /api/notices/crawl
```

**요청 Body (JSON)**:
```json
{
  "max_pages": 2,
  "categories": ["공지사항", "학사/장학"]
}
```

**응답**:
```json
{
  "status": "success",
  "data": {
    "crawled": 30,
    "inserted": 25,
    "duplicates": 5,
    "errors": 0
  }
}
```

**cURL 예시**:
```bash
curl -X POST http://localhost:5000/api/notices/crawl \
  -H "Content-Type: application/json" \
  -d '{"max_pages": 2}'
```

---

### 2. 공지사항 목록 조회
```
GET /api/notices?category=공지사항&limit=20&offset=0
```

**쿼리 파라미터**:
- `category` (선택): 카테고리 필터 ("공지사항", "학사/장학", "모집공고")
- `limit` (선택): 가져올 개수 (기본 20)
- `offset` (선택): 건너뛸 개수 (기본 0)

**응답**:
```json
{
  "status": "success",
  "data": [
    {
      "id": "uuid",
      "title": "2024학년도 1학기 수강신청 안내",
      "content": "수강신청 일정 안내...",
      "category": "공지사항",
      "source_url": "https://...",
      "published_at": "2024-01-20T00:00:00",
      "crawled_at": "2024-01-23T10:00:00"
    }
  ],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "count": 15
  }
}
```

**cURL 예시**:
```bash
# 전체 조회
curl http://localhost:5000/api/notices

# 카테고리 필터
curl http://localhost:5000/api/notices?category=공지사항

# 페이지네이션
curl http://localhost:5000/api/notices?limit=10&offset=20
```

---

### 3. 특정 공지사항 조회
```
GET /api/notices/{notice_id}
```

**응답**:
```json
{
  "status": "success",
  "data": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "title": "제목",
    "content": "내용",
    "category": "공지사항",
    "source_url": "https://...",
    "published_at": "2024-01-20T00:00:00"
  }
}
```

**cURL 예시**:
```bash
curl http://localhost:5000/api/notices/123e4567-e89b-12d3-a456-426614174000
```

---

### 4. 공지사항 삭제
```
DELETE /api/notices/{notice_id}
```

**응답**:
```json
{
  "status": "success",
  "message": "삭제되었습니다"
}
```

**cURL 예시**:
```bash
curl -X DELETE http://localhost:5000/api/notices/123e4567-e89b-12d3-a456-426614174000
```

---

### 5. 통계 조회
```
GET /api/notices/stats
```

**응답**:
```json
{
  "status": "success",
  "data": {
    "total": 150,
    "by_category": {
      "공지사항": 100,
      "학사/장학": 30,
      "모집공고": 20
    },
    "last_updated": "2024-01-23T10:00:00"
  }
}
```

**cURL 예시**:
```bash
curl http://localhost:5000/api/notices/stats
```

---

## 🚀 사용 예시 (Python)

### 크롤링 후 저장
```python
import requests

# 공지사항 크롤링
response = requests.post('http://localhost:5000/api/notices/crawl', json={
    "max_pages": 2,
    "categories": ["공지사항"]
})

result = response.json()
print(f"크롤링: {result['data']['crawled']}개")
print(f"저장: {result['data']['inserted']}개")
```

### 목록 조회
```python
import requests

# 공지사항 목록 조회
response = requests.get('http://localhost:5000/api/notices', params={
    "category": "공지사항",
    "limit": 10
})

notices = response.json()['data']
for notice in notices:
    print(f"[{notice['category']}] {notice['title']}")
```

---

## 💡 Workflow 예시

### 1. 최초 데이터 수집
```bash
# 전체 공지사항 크롤링 (각 3페이지)
curl -X POST http://localhost:5000/api/notices/crawl \
  -H "Content-Type: application/json" \
  -d '{"max_pages": 3}'
```

### 2. 데이터 확인
```bash
# 통계 확인
curl http://localhost:5000/api/notices/stats

# 최신 공지 20개 조회
curl http://localhost:5000/api/notices?limit=20
```

### 3. 주기적 업데이트 (새 공지만 가져오기)
```bash
# 최신 1페이지만 크롤링 (중복은 자동 제외)
curl -X POST http://localhost:5000/api/notices/crawl \
  -H "Content-Type: application/json" \
  -d '{"max_pages": 1}'
```

---

## ⚠️ 주의사항

1. **환경 변수 설정 필수**
   - `SUPABASE_URL`: Supabase 프로젝트 URL
   - `SUPABASE_KEY`: Supabase anon key

2. **중복 처리**
   - `source_url` 기준으로 자동 중복 제거
   - 이미 있는 공지는 `duplicates` 카운트에 포함

3. **에러 처리**
   - 크롤링 실패한 공지는 `errors` 카운트에 포함
   - 전체 작업은 계속 진행됨

4. **성능**
   - 페이지당 약 10개 공지사항
   - 각 공지사항당 상세 페이지 요청 발생
   - max_pages=3 → 약 30초 소요
