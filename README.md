# Ink-ventory

베스트펜, 블루블랙, 펜갤러리아, 펜로그의 **화면에 공개된 만년필** 가격·재고를 확인하고 사용자별 이메일 알림을 보내는 Rails 서비스입니다.

## 구성

- Ruby 3.4 / Rails 8.1 / SQLite
- 서버 렌더링 HTML, Google·Kakao OAuth
- `Net::HTTP` + Nokogiri 수집기 (별도 브라우저 없음)
- SQLite 기반 Solid Queue 작업 처리
- 개발: Rails 단일 컨테이너
- 운영: Caddy HTTPS + Rails 단일 애플리케이션 컨테이너

같은 정규 URL은 `listings.canonical_url` 고유키로 전체 사용자에게서 하나로 합칩니다. 최초 수집은 기준값만 저장하고, 변화가 1분 이상 뒤 재확인될 때 이벤트를 확정합니다. 파싱 실패나 타임아웃은 품절로 바꾸지 않습니다.

## Docker 개발 시작

```bash
cp .env.example .env
docker compose build
docker compose up
```

브라우저에서 `http://localhost:3300`을 엽니다. 첫 실행 때 Rails 컨테이너가 `db:prepare`를 수행하고 백그라운드 작업도 함께 실행합니다. SQLite 파일은 Docker 볼륨에 보관됩니다.

3300번 포트를 이미 사용 중이면 `.env`의 `APP_PORT`를 다른 값으로 바꿀 수 있습니다.

- 매분: 기한이 된 상품 수집, 변화 재확인, 메일 재시도
- 매일 01:00 KST: 네 쇼핑몰의 만년필 카테고리에서 신규 상품 발견
- 매일 02:00 KST: 저장된 검색어의 신규 후보 확인
- 매일 20:00 KST: 사용자별 요약 생성
- 매일 03:00 KST: 30일 지난 발송 로그 정리

개발 환경 메일은 실제로 발송하지 않고 `tmp/mails`에 저장됩니다.

### 테스트

```bash
docker compose run --rm -e RAILS_ENV=test web bin/rails db:prepare
docker compose run --rm -e RAILS_ENV=test web bin/rails test
```

### Google / Kakao 로그인

`.env`에 각 공급자의 키를 넣습니다. 키가 비어 있으면 해당 로그인 버튼을 숨깁니다.

```dotenv
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
KAKAO_CLIENT_ID=...
KAKAO_CLIENT_SECRET=...
```

개발 콜백 URL은 다음과 같습니다.

- Google: `http://localhost:3300/auth/google_oauth2/callback`
- Kakao: `http://localhost:3300/auth/kakao/callback`

관리자로 지정할 소셜 계정 이메일은 `ADMIN_EMAILS=admin@example.com,other@example.com`처럼 설정합니다.

## 수집 규칙

- 허용 HTTPS 호스트와 상품 번호를 검사하고 PC·모바일 URL을 정규화합니다.
- 모든 DNS 응답이 공인 IP일 때만 요청하며, 리디렉션 후에도 같은 검사를 반복합니다.
- 사이트별 요청은 한 번에 하나, 최소 2초 간격과 지터를 적용합니다.
- `403`, `429`, 반복 `5xx`는 사이트 단위 지수 백오프를 적용하며 관리 화면에서 긴급 중지할 수 있습니다.
- JSON-LD, 화면의 옵션명·가격·품절 표기만 읽습니다. 스크립트나 숨김 필드의 재고 숫자, 장바구니 시험은 사용하지 않습니다.
- 상품 404는 세 번 연속 확인된 뒤 판매 종료로 확정합니다.

사이트 HTML이 바뀌면 `test/services/store_parser_test.rb`의 해당 fixture를 먼저 갱신해 회귀 테스트를 추가합니다. 운영 전 각 판매처의 robots/이용약관과 자동 조회 허용 범위를 다시 확인하고, `CRAWLER_USER_AGENT`에 실제 서비스명과 연락처를 넣으세요.

## 운영 배포

1. `.env.production`을 만들고 `SECRET_KEY_BASE`, OAuth 키, 도메인, SES SMTP 자격 증명을 설정합니다.
2. DNS에서 `APP_HOST`를 서버로 연결합니다.
3. SES 서울 리전에서 발신 도메인을 인증하고 SPF·DKIM·DMARC 및 프로덕션 발송 승인을 완료합니다.
4. 아래 명령으로 시작합니다.

```bash
docker compose -f compose.production.yaml up -d --build
docker compose -f compose.production.yaml exec web bin/rails db:seed
curl -f https://YOUR_DOMAIN/up
```

필수 운영 환경 변수 예시:

```dotenv
DATABASE_PATH=/rails/storage/production.sqlite3
APP_HOST=inventory.example.com
SECRET_KEY_BASE=...
SMTP_HOST=email-smtp.ap-northeast-2.amazonaws.com
SMTP_PORT=587
SMTP_USERNAME=...
SMTP_PASSWORD=...
MAIL_FROM=Ink-ventory <alerts@inventory.example.com>
CONTACT_EMAIL=ops@example.com
CRAWLER_USER_AGENT=Ink-ventory/1.0 (+mailto:ops@example.com)
```

Rails 컨테이너 안에서 실행되는 Solid Queue recurring scheduler가 호스트 cron과 `flock` 역할을 대신합니다. 한 작업의 중복 실행은 Solid Queue 동시성 제한으로 막습니다.

### 백업

호스트 cron에서 하루 한 번 실행합니다. 일간 7일, 일요일 사본은 주간 4주를 보관합니다.

```cron
20 3 * * * cd /srv/ink-ventory && flock -n /tmp/ink-ventory-backup.lock sh -a -c '. ./.env.production; ./script/backup'
```

복원할 때는 잠시 서비스 사용을 중단한 뒤 실행합니다.

```bash
set -a; . ./.env.production; set +a
./script/restore backups/daily/ink-ventory-YYYYMMDD-HHMMSS.sqlite3
```

## 공개 전 확인

- 개인정보 처리방침의 실제 운영자명·연락처·위탁 사업자 확정
- Google/Kakao 운영 앱과 콜백 URL 등록
- SES 테스트 발송, 수신 중지 링크, 일일 요약 확인
- 네 판매처의 URL 등록·검색·복수 옵션 fixture를 실제 페이지로 재검증
- Caddy HTTPS, `/up`, PostgreSQL 백업 복원 스모크 테스트
