# 🛡️ AIX-Boost 보안 감사 리포트

**진단 일시**: 2026-01-27  
**점검 대상**: Backend (Flask), Frontend (Flutter)  
**진단 기준**: OWASP MASVS (Mobile App Security Verification Standard), 보안 코딩 가이드라인

---

## 🚨 긴급 조치 필요 사항 (Critical Priorities)

### 1. 백엔드 API 인증 메커니즘 부재
- **위치**: `backend/routes/notices.py`
- **문제점**: `/api/notices/crawl` (크롤링 실행) 및 `/api/notices/<id>` (삭제) API가 별도의 인증 절차 없이 `POST`/`DELETE` 요청을 허용하고 있습니다.
- **위험도**: **[치명적]** 악의적인 사용자가 무한 크롤링을 트리거하여 서버 자원을 고갈시키거나(DoS), 데이터를 무단으로 삭제할 수 있습니다.
- **권장 조치**: 
  - 요청 헤더의 `Authorization` 토큰(Supabase JWT)을 검증하는 미들웨어 또는 데코레이터를 모든 관리자급 API에 적용해야 합니다.
  - Supabase Auth를 활용하여 `role` 기반 접근 제어(RBAC)를 구현하세요.

### 2. 로깅 보안 취약점
- **위치**: `backend/routes/notices.py`, `backend/services/supabase_service.py` 등
- **문제점**: `print()` 함수를 사용하여 크롤링 데이터나 에러 메시지를 표준 출력으로 내보내고 있습니다.
- **위험도**: **[높음]** 프로덕션 환경에서 시스템 로그에 민감한 데이터가 평문으로 기록될 수 있습니다.
- **권장 조치**: Python의 `logging` 모듈을 도입하고, 로그 레벨(INFO, ERROR)을 관리하며 민감 정보는 마스킹 처리해야 합니다.

---

## 🔍 상세 점검 결과 (Checklist)

### 1. 💾 데이터 저장 및 관리 (Data Storage & Privacy)

| 항목 | 상태 | 상세 분석 |
|---|---|---|
| **하드코딩 점검** | ⚠️ 주의 | `backend/config.py`에 `SECRET_KEY` 기본값이 존재합니다. 프로덕션 환경에서는 반드시 환경변수로만 주입되도록 강제해야 합니다. |
| **로컬 저장소 암호화** | ⚠️ 주의 | Frontend에서 `shared_preferences`를 사용 중입니다. 단순 설정값이 아닌 사용자 토큰 등 민감 정보 저장 시에는 `flutter_secure_storage`를 사용하여 OS 키체인에 암호화 저장해야 합니다. |
| **DB 보안 (RLS)** | ✅ 양호 | `docs/database_schema.sql` 확인 결과, `ENABLE ROW LEVEL SECURITY`가 적용되어 있으며, 사용자 본인 데이터만 접근하도록 정책(Policy)이 잘 수립되어 있습니다. |
| **캐시/임시파일** | 📝 정보 | 크롤러나 앱에서 생성되는 임시 파일이 디바이스/서버에 잔존하지 않도록 주기적인 삭제 로직이 필요합니다. |

### 2. 🌐 네트워크 통신 (Network Communication)

| 항목 | 상태 | 상세 분석 |
|---|---|---|
| **HTTPS 강제** | ⚠️ 주의 | `backend/app.py`는 기본 HTTP로 실행됩니다. 실 서비스 배포 시 Gunicorn/Nginx 등을 앞단에 두어 HTTPS(SSL/TLS)를 적용해야 합니다. |
| **SSL Pinning** | ❌ 미적용 | Frontend `api_service.dart`에 SSL Pinning 설정이 없습니다. 중간자 공격(MITM) 방지를 위해 인증서 고정(Pinning) 로직 추가가 필요합니다. |
| **평문 통신** | ⚠️ 주의 | 개발 환경(`localhost`)에서는 허용되나, 배포 설정(`frontend/lib/services/api_service.dart`)에서 `http://` 주소 사용을 차단해야 합니다. |

### 3. 🔐 인증 및 인가 (Authentication & Authorization)

| 항목 | 상태 | 상세 분석 |
|---|---|---|
| **API 키 관리** | ✅ 양호 | `.env` 파일을 통해 관리되고 있으며 `.gitignore`에 포함되어 있어 Git에 노출될 위험은 적습니다. |
| **세션 관리** | ⚠️ 주의 | Frontend에서 JWT 토큰의 유효기간 만료 시 자동 갱신(Refresh) 로직이 구현되어 있는지 확인이 필요합니다. |

### 4. 📱 모바일 앱 보안 (App Security)

| 항목 | 상태 | 상세 분석 |
|---|---|---|
| **코드 난독화** | ❌ 불가 | 현재 프로젝트 구조상 `android`, `ios` 네이티브 폴더가 생성되지 않아 ProGuard/R8 설정을 확인할 수 없습니다. 앱 빌드 전 `flutter create .` 등을 통해 플랫폼 폴더 생성 후 설정해야 합니다. |
| **루팅/탈옥 탐지** | ❌ 미적용 | `flutter_jailbreak_detection` 등의 패키지를 사용하여 위변조된 OS에서의 실행을 차단해야 합니다. |
| **권한 최소화** | ❓ 미확인 | `AndroidManifest.xml`이 없어 확인 불가하나, 인터넷 권한 외 불필요한 권한(위치, 카메라 등)은 요청하지 않도록 주의해야 합니다. |

---

## 🛠️ 향후 보안 강화 로드맵 (Action Items)

### [즉시 실행]
1. **API 인증 미들웨어 구현**: 백엔드에 JWT 검증 로직 추가.
2. **네이티브 플랫폼 설정**: `frontend`에서 `flutter create .` 실행하여 Android/iOS 프로젝트 생성.
3. **Flutter Secure Storage 도입**: `shared_preferences` 대신 보안 저장소 사용.

### [배포 전 실행]
1. **코드 난독화 설정**: Android `build.gradle`에 `minifyEnabled true`, `shrinkResources true` 설정.
2. **HTTPS 적용**: 서버 배포 시 SSL 인증서 적용.
3. **입력값 검증 강화**: SQL Injection 방지는 ORM/Supabase 라이브러리로 방어가 되지만, XSS 방지를 위해 Frontend 출력부 검증 필요.
