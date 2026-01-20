#!/bin/bash

# AIX-Boost 프로젝트 초기 설정 스크립트

echo "🚀 AIX-Boost 프로젝트 초기화 시작..."

# 현재 디렉토리 확인
if [ ! -f "CLAUDE.md" ]; then
    echo "❌ 오류: 프로젝트 루트 디렉토리에서 실행해주세요."
    exit 1
fi

# 1. Git 초기화 (이미 되어있지 않다면)
if [ ! -d ".git" ]; then
    echo "📦 Git 저장소 초기화 중..."
    git init
    git checkout -b main
else
    echo "✅ Git 저장소가 이미 초기화되어 있습니다."
fi

# 2. develop 브랜치 생성
echo "🌿 develop 브랜치 생성 중..."
git checkout -b develop 2>/dev/null || git checkout develop

# 3. .env 파일 생성
echo "🔐 환경 변수 파일 생성 중..."

if [ ! -f "backend/.env" ]; then
    cp backend/.env.example backend/.env
    echo "✅ backend/.env 생성 완료 (실제 값으로 수정 필요)"
else
    echo "⚠️  backend/.env 이미 존재함"
fi

if [ ! -f "frontend/.env" ]; then
    cp frontend/.env.example frontend/.env
    echo "✅ frontend/.env 생성 완료 (실제 값으로 수정 필요)"
else
    echo "⚠️  frontend/.env 이미 존재함"
fi

# 4. Backend 의존성 설치 (선택)
read -p "Backend Python 의존성을 설치하시겠습니까? (y/N): " install_backend
if [ "$install_backend" = "y" ] || [ "$install_backend" = "Y" ]; then
    echo "🐍 Python 패키지 설치 중..."
    cd backend
    pip install -r requirements.txt
    cd ..
    echo "✅ Backend 의존성 설치 완료"
fi

# 5. Frontend 의존성 설치 (선택)
read -p "Frontend Flutter 의존성을 설치하시겠습니까? (y/N): " install_frontend
if [ "$install_frontend" = "y" ] || [ "$install_frontend" = "Y" ]; then
    if command -v flutter &> /dev/null; then
        echo "📱 Flutter 패키지 설치 중..."
        cd frontend
        flutter pub get
        cd ..
        echo "✅ Frontend 의존성 설치 완료"
    else
        echo "⚠️  Flutter가 설치되어 있지 않습니다. 건너뜁니다."
    fi
fi

# 6. 초기 커밋 (선택)
read -p "초기 설정을 커밋하시겠습니까? (y/N): " do_commit
if [ "$do_commit" = "y" ] || [ "$do_commit" = "Y" ]; then
    echo "💾 초기 커밋 생성 중..."
    git add .
    git commit -m "[Init] 프로젝트 초기 설정

- Backend (Flask) 초기 파일 생성
- Frontend (Flutter) 초기 파일 생성
- API 명세서 및 DB 스키마 작성
- 협업 가이드 문서 작성
- GitHub Actions CI/CD 설정

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
    echo "✅ 초기 커밋 완료"
fi

echo ""
echo "✨ 프로젝트 초기화 완료!"
echo ""
echo "📋 다음 단계:"
echo "1. backend/.env와 frontend/.env 파일을 열어 실제 API 키 입력"
echo "2. GitHub 저장소 생성 후 연결:"
echo "   git remote add origin <your-repo-url>"
echo "   git push -u origin develop"
echo "3. 협업 가이드 확인: docs/COLLABORATION_GUIDE.md"
echo "4. Backend 실행: cd backend && python app.py"
echo "5. Frontend 실행: cd frontend && flutter run"
echo ""
echo "🎉 즐거운 개발 되세요!"
