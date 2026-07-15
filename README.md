# Ink-ventory

베스트펜, 블루블랙, 펜갤러리아, 펜로그의 **화면에 공개된 만년필** 가격·재고를 확인하고 사용자별 이메일 알림을 보내는 Rails 서비스입니다.

## 구성

- Ruby 3.4 / Rails 8.1 / SQLite
- 서버 렌더링 HTML, 이메일 인증번호 로그인
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
- 매일 03:00 KST: 30일 지난 발송 로그 정리

개발 환경은 SMTP 자격 증명이 없으면 메일을 `tmp/mails`에 저장하고, `.env`에 자격 증명이 있으면 SES로 발송합니다.

### 테스트

```bash
docker compose run --rm -e RAILS_ENV=test web bin/rails db:prepare
docker compose run --rm -e RAILS_ENV=test web bin/rails test
```

### 이메일 로그인

사용자는 이메일로 받은 6자리 인증번호를 입력해 로그인합니다. 인증번호는 10분 동안 한 번만 사용할 수 있으며, 로그인 이메일을 재입고·품절·가격 알림 주소로 함께 사용합니다.

관리자로 지정할 이메일은 `ADMIN_EMAILS=admin@example.com,other@example.com`처럼 설정합니다.

## 수집 규칙

- 허용 HTTPS 호스트와 상품 번호를 검사하고 PC·모바일 URL을 정규화합니다.
- 모든 DNS 응답이 공인 IP일 때만 요청하며, 리디렉션 후에도 같은 검사를 반복합니다.
- 사이트별 요청은 한 번에 하나, 최소 2초 간격과 지터를 적용합니다.
- `403`, `429`, 반복 `5xx`는 사이트 단위 지수 백오프를 적용하며 관리 화면에서 긴급 중지할 수 있습니다.
- JSON-LD와 화면에서 상품명·기본 가격·상품 전체 재고만 읽고 옵션 정보는 저장하지 않습니다. 스크립트나 숨김 필드의 재고 숫자, 장바구니 시험은 사용하지 않습니다.
- 상품 404는 세 번 연속 확인된 뒤 판매 종료로 확정합니다.

사이트 HTML이 바뀌면 `test/services/store_parser_test.rb`의 해당 fixture를 먼저 갱신해 회귀 테스트를 추가합니다. 운영 전 각 판매처의 robots/이용약관과 자동 조회 허용 범위를 다시 확인하고, `CRAWLER_USER_AGENT`에 실제 서비스명과 연락처를 넣으세요.

## 운영 배포

1. `.env.example`을 복사해 `.env`를 만들고 `SECRET_KEY_BASE`, 도메인, SES SMTP 자격 증명을 설정합니다.
2. DNS에서 `APP_HOST`를 서버로 연결합니다.
3. SES 서울 리전에서 발신 도메인을 인증하고 SPF·DKIM·DMARC 및 프로덕션 발송 승인을 완료합니다.
4. 아래 명령으로 시작합니다.

```bash
docker compose -f compose.production.yaml up -d --build
docker compose -f compose.production.yaml exec web bin/rails db:seed
docker compose -f compose.production.yaml exec web bin/rails runner 'DiscoverCatalogsJob.perform_now'
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
20 3 * * * cd /srv/ink-ventory && flock -n /tmp/ink-ventory-backup.lock sh -a -c '. ./.env; ./script/backup'
```

복원할 때는 잠시 서비스 사용을 중단한 뒤 실행합니다.

```bash
set -a; . ./.env; set +a
./script/restore backups/daily/ink-ventory-YYYYMMDD-HHMMSS.sqlite3
```

## 공개 전 확인

- 개인정보 처리방침의 실제 운영자명·연락처·위탁 사업자 확정
- 이메일 인증번호 로그인과 재발급 제한 확인
- SES 테스트 발송과 수신 중지 링크 확인
- 네 판매처의 URL 등록·검색·상품 전체 재고 fixture를 실제 페이지로 재검증
- Caddy HTTPS, `/up`, SQLite 백업 복원 스모크 테스트
