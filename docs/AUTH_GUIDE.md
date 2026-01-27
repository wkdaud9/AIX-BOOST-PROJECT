# 🔐 AIX-Boost 인증 시스템 가이드 (Authentication Guide)

이 문서는 프로젝트의 인증 시스템 구조와 구현 방법, 그리고 인수인계 시 알아야 할 보안 사항을 정리한 가이드입니다.

---

## 1. 🏗️ 전체 구조 (Architecture)

우리는 **Supabase Auth**를 메인 인증 제공자로 사용하며, 프론트엔드와 백엔드가 JWT 토큰을 공유하는 방식을 채택했습니다.

### 🔄 인증 흐름 (Authentication Flow)

1.  **로그인 (Frontend)**: 사용자가 앱에서 이메일/비밀번호로 로그인합니다. (Supabase Auth 사용)
2.  **토큰 발급**: Supabase가 유효한 `Access Token` (JWT)을 프론트엔드에 반환합니다.
3.  **토큰 설정**: `AuthService`가 이 토큰을 받아서 `ApiService`의 HTTP 헤더(`Authorization: Bearer <token>`)에 자동으로 심어줍니다.
4.  **API 호출**: 프론트엔드가 백엔드 API를 호출할 때마다 이 토큰이 함께 전송됩니다.
5.  **토큰 검증 (Backend)**: Flask 백엔드의 `@login_required` 데코레이터가 토큰을 가로채서 Supabase에 유효성을 확인합니다.
6.  **접근 허용/거부**: 토큰이 유효하면 API 로직을 실행하고, 아니면 `401 Unauthorized`를 반환합니다.

---

## 2. ⚙️ 설정 방법 (Setup)

### Frontend 설정 (`frontend/.env`)
Supabase 프로젝트 설정값을 `.env` 파일에 반드시 추가해야 합니다.

```properties
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR...
```

### Backend 설정 (`backend/.env`)
백엔드도 동일한 Supabase 프로젝트를 바라봐야 합니다.

```properties
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR... (Service Role Key 권장)
```

---

## 3. 💻 개발 가이드 (Development)

### A. 프론트엔드: 로그인 구현하기
`AuthService`를 사용하여 쉽게 로그인 기능을 구현할 수 있습니다.

```dart
// Provider로 AuthService 가져오기
final authService = context.read<AuthService>();

// 로그인 시도
try {
  await authService.signIn('email@example.com', 'password123');
  // 성공 시 자동으로 ApiService에 토큰이 설정됨!
} catch (e) {
  // 실패 처리
}
```

### B. 백엔드: API 보호하기
새로운 관리자용 API를 만들 때 `@login_required`만 붙이면 됩니다.

```python
from utils.auth_middleware import login_required

@bp.route('/admin/secret', methods=['POST'])
@login_required  # <--- 이거 하나면 보안 완료!
def secret_action():
    return "Admin only!"
```

---

## 4. 🚨 보안 정책 (Security Policies)

### 현재 보호되고 있는 API
다음 API들은 반드시 **로그인한 사용자(유효한 토큰 보유자)**만 호출할 수 있습니다.
- `POST /api/notices/crawl`: 공지사항 크롤링 트리거
- `DELETE /api/notices/<id>`: 공지사항 삭제

### 공개된 API (Public)
다음 API들은 로그인 없이 호출 가능합니다.
- `GET /api/notices`: 공지사항 목록 조회
- `GET /api/notices/<id>`: 상세 조회
- `GET /health`: 서버 헬스 체크

---

## 5. 📝 인수인계 체크리스트
- [ ] Supabase 프로젝트 생성 및 URL/Key 발급 완료했나요?
- [ ] Supabase 대시보드에서 `Email Auth`가 활성화되어 있나요?
- [ ] `frontend/.env` 파일을 생성했나요?
