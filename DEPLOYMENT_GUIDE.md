# 🚀 AIX-Boost 배포 가이드

Render에 Flask 서버를 배포하고 24시간 운영하는 방법입니다.

## 📋 목차
1. [Render 배포](#1-render-배포)
2. [GitHub Actions 설정](#2-github-actions-설정)
3. [환경 변수 설정](#3-환경-변수-설정)
4. [배포 확인](#4-배포-확인)

---

## 1. Render 배포

### 1.1. Render 계정 생성
1. [render.com](https://render.com) 접속
2. GitHub 계정으로 로그인

### 1.2. 새 Web Service 생성
1. Dashboard → **"New +"** → **"Web Service"**
2. GitHub 리포지토리 연결
   - `AIX-BOOST-PROJECT` 선택
3. 설정:
   - **Name**: `aix-boost-backend`
   - **Region**: `Singapore` (또는 가까운 리전)
   - **Runtime**: `Python 3`
   - **Build Command**:
     ```bash
     pip install -r backend/requirements.txt
     ```
   - **Start Command**:
     ```bash
     python backend/app.py
     ```
   - **Plan**: **Free**

### 1.3. 환경 변수 설정
"Environment" 탭에서 다음 변수들을 추가:

| Key | Value | 설명 |
|-----|-------|------|
| `SUPABASE_URL` | `https://xxx.supabase.co` | Supabase 프로젝트 URL |
| `SUPABASE_KEY` | `eyJxxx...` | Supabase API Key (anon/public) |
| `GEMINI_API_KEY` | `AIzaXxx...` | Google Gemini API Key |
| `PORT` | `10000` | Render 기본 포트 |
| `FLASK_ENV` | `production` | Flask 환경 |

**⚠️ 주의**: 환경 변수 수정 후 **"Save Changes"** 클릭!

### 1.4. 배포 시작
1. **"Create Web Service"** 클릭
2. 자동으로 빌드 및 배포 시작
3. 5~10분 소요
4. 배포 완료 후 URL 확인:
   ```
   https://aix-boost-backend.onrender.com
   ```

---

## 2. GitHub Actions 설정

### 2.1. 목적
- **14분마다** `/health` 엔드포인트를 ping
- Render 서버가 15분 후 sleep되는 것을 방지
- → **서버가 24시간 깨어있게 유지**

### 2.2. 설정 확인
`.github/workflows/keep-alive.yml` 파일이 이미 생성되어 있습니다.

### 2.3. GitHub Actions 활성화
1. GitHub 리포지토리 → **"Actions"** 탭
2. "I understand my workflows, go ahead and enable them" 클릭
3. 자동으로 14분마다 실행됨 ✅

### 2.4. 수동 실행 (테스트용)
1. **Actions** 탭 → `Keep Render Server Alive` 선택
2. **"Run workflow"** → **"Run workflow"** 클릭
3. 실행 로그 확인

---

## 3. 환경 변수 설정

### 3.1. Supabase 설정

#### Supabase URL 및 API Key 가져오기
1. [supabase.com](https://supabase.com) → 프로젝트 선택
2. **Settings** → **API**
3. 복사:
   - **Project URL**: `https://xxx.supabase.co`
   - **anon/public key**: `eyJxxx...`

#### Render에 추가
1. Render Dashboard → `aix-boost-backend` 선택
2. **Environment** 탭
3. 위 값들을 `SUPABASE_URL`, `SUPABASE_KEY`에 입력

### 3.2. Gemini API Key 설정

#### API Key 발급
1. [Google AI Studio](https://aistudio.google.com/app/apikey) 접속
2. **"Create API Key"** 클릭
3. 기존 Google Cloud 프로젝트 선택 또는 새로 생성
4. API Key 복사: `AIzaXxx...`

#### Render에 추가
1. Render Dashboard → `aix-boost-backend` 선택
2. **Environment** 탭
3. `GEMINI_API_KEY`에 입력

---

## 4. 배포 확인

### 4.1. 서버 헬스 체크
브라우저에서 접속:
```
https://aix-boost-backend.onrender.com/health
```

**정상 응답:**
```json
{
  "status": "ok",
  "message": "AIX-Boost API Server is running",
  "timestamp": "2026-02-03T10:30:00",
  "crawl_status": {
    "is_running": false,
    "last_run": null
  }
}
```

### 4.2. API 엔드포인트 확인

#### 루트 엔드포인트
```
GET https://aix-boost-backend.onrender.com/
```

#### 공지사항 목록 조회
```
GET https://aix-boost-backend.onrender.com/api/notices?limit=10
```

#### 크롤링 수동 실행
```bash
curl -X POST https://aix-boost-backend.onrender.com/api/crawl
```

#### 크롤링 상태 확인
```
GET https://aix-boost-backend.onrender.com/api/crawl/status
```

#### 스케줄러 상태 확인
```
GET https://aix-boost-backend.onrender.com/scheduler/status
```

### 4.3. 로그 확인
1. Render Dashboard → `aix-boost-backend` 선택
2. **Logs** 탭
3. 실시간 로그 확인

**정상 로그 예시:**
```
[AIX-Boost] Backend starting on port 10000
[스케줄러] 자동 크롤링 스케줄러 시작
[스케줄러] 실행 주기: 15분마다
```

---

## 5. 시간 사용량 확인

### 무료 플랜 시간
- **무료 시간**: 750시간/월
- **24시간 운영**: 24 × 31 = 744시간
- **여유**: 6시간 ✅

### 시간 확인 방법
1. Render Dashboard → **"Billing"**
2. "Usage This Month" 확인
3. 750시간 이내인지 체크

---

## 6. Flutter 앱 연동

### 6.1. API Base URL 설정
Flutter 앱에서 다음 URL을 사용:
```dart
const String API_BASE_URL = 'https://aix-boost-backend.onrender.com';
```

### 6.2. 공지사항 조회 예시
```dart
// 공지사항 목록
GET $API_BASE_URL/api/notices?limit=20

// 사용자 맞춤 공지
GET $API_BASE_URL/api/user/{userId}/notices?min_score=0.5
```

---

## 7. 문제 해결

### 서버가 응답하지 않을 때
1. **Cold Start**: 첫 요청 시 30초~1분 소요 (정상)
2. **GitHub Actions 확인**: Actions 탭에서 실행 중인지 확인
3. **환경 변수 확인**: Render Environment 탭에서 모든 변수 설정 확인
4. **로그 확인**: Render Logs 탭에서 에러 확인

### 크롤링이 실행되지 않을 때
1. **스케줄러 상태 확인**:
   ```
   GET /scheduler/status
   ```
2. **수동 실행 테스트**:
   ```bash
   curl -X POST https://aix-boost-backend.onrender.com/api/crawl
   ```
3. **로그 확인**: `[스케줄러]` 로그 검색

### GitHub Actions 실패 시
1. **Actions** 탭 → 실패한 workflow 클릭
2. 에러 메시지 확인
3. 대부분 서버 URL이 잘못되었거나 서버가 다운된 경우

---

## 8. 운영 팁

### 서버 항상 깨어있게 유지
- ✅ GitHub Actions가 14분마다 자동으로 ping
- ✅ 서버 스케줄러가 15분마다 자동 크롤링
- → **서버가 절대 sleep 안 됨!**

### 안드로이드 테스트
```
https://aix-boost-backend.onrender.com/api/notices
```
위 URL을 Flutter 앱에서 사용하면 실기기에서도 정상 동작합니다.

### 비용 절감
- 무료 플랜: 750시간/월
- 현재 사용량: ~744시간/월
- 2달 운영 예정 → **완전 무료** 🎉

---

## 9. 체크리스트

배포 완료 후 다음 항목들을 확인하세요:

- [ ] Render 서버 배포 완료
- [ ] `/health` 엔드포인트 정상 응답
- [ ] 환경 변수 모두 설정 (SUPABASE_URL, SUPABASE_KEY, GEMINI_API_KEY)
- [ ] GitHub Actions 활성화 및 14분마다 실행 중
- [ ] 스케줄러 상태 확인 (`/scheduler/status`)
- [ ] 크롤링 수동 실행 테스트 완료
- [ ] Flutter 앱에서 API 호출 테스트 완료
- [ ] 안드로이드 실기기에서 테스트 완료

---

## 📞 문의

문제가 발생하면:
1. Render Logs 확인
2. GitHub Actions 로그 확인
3. `/api/crawl/status` 및 `/scheduler/status` 확인

배포 완료! 🎉
