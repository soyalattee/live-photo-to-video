# 런칭까지 남은 작업 (TODO)

> auto-photos iOS 앱 앱스토어 런칭 계획. 결정된 설계 기준 작업 목록.
> 작성일: 2026-05-30 / 번들 ID: `soya.auto-photos` / 배포 타겟: iOS 16.0

## 확정된 핵심 결정 사항

- **결제**: 주간 $1.99 단일 구독, 무료체험·연간 없음. Product ID `soya.auto-photos.weekly` (StoreKit 2)
- **프리미엄 게이팅**: 프리미엄 템플릿도 **선택·생성·미리보기는 무료**. 게이팅은 **다운로드 시점**에만.
  - 비구독자는 **광고 1회 시청 또는 구독** 해야 다운로드 가능. 둘 다 아니면 **다운로드 불가**(페이월 표시)
- **광고**: AdMob 보상형. 프리미엄 영상 다운로드 시 광고 1회 시청 → 다운로드. (24시간 제한 정책 폐기, "볼 때마다" 다운로드)
- **워터마크**: 받을 로고 PNG(투명배경)를 반투명 적용. **다운로드 시 워터마크 필수**, **구독자만 제거**.
  - 광고 시청 후 다운로드도 워터마크 **유지** (광고로는 워터마크 제거 안 됨)
- **템플릿 구성**: 무료 3 / 프리미엄 2 = 총 5개
  - 무료: `restaurantRecommendation`(오늘의 픽), 새 템플릿(컨셉 미정)
  - 프리미엄: `lockScreenLog`, `lifeInFraems`
  - 목록에서 제거: `restaurantShortForm`(추천 릴스), `allPhotosFlow`

---

## 0. 선결 / 블로킹 항목

- [ ] **Apple Developer Program 등록 상태 확인** ($99/년). 미등록 시 실기기 테스트·StoreKit 실거래·AdMob·심사 전부 불가
  - 주의: 미커밋 diff에서 `DEVELOPMENT_TEAM`이 빈 문자열 → `LR5K2G2WSV`로 다시 설정됨 → 실제 등록 여부 확인 필요
- [ ] 같은 폴더에서 동시 실행 중인 다른 Claude/에디터 세션 종료 (파일 충돌·임시디스크 문제 방지)
- [ ] 빌드/테스트용 임시 디스크 공간 확보 (`CLAUDE_CODE_TMPDIR` 여유 경로 지정 검토)

---

## 1. 워터마크 변경 — ✅ 거의 완료 (스펙 미세조정만 남음)

- [x] **로고 워터마크 이미지(PNG, 투명배경) 수령** — `auto-photos/Resources/Brand/wartermark.png` (286KB) 존재
- [x] 로고 에셋 등록 — `Resources/` 는 Xcode 동기화 폴더(`PBXFileSystemSynchronizedRootGroup`)라 자동 번들 포함
- [x] `DefaultVideoGenerationService`에 워터마크 오버레이 레이어 추가 (`addWatermarkLayer`, 불투명도 0.42)
- [x] 워터마크 적용 조건 로직: `saveGeneratedVideo()`가 `VideoRenderOptions.appliesWatermark`로 게이팅 (구독자/무료 분기)
- [x] 렌더 캐시 키에 워터마크 반영 — `VideoRenderCacheKey`가 `VideoRenderOptions`(Hashable, `appliesWatermark` 포함) 사용
- [x] 정책 확정 — 광고 시청 후에도 비구독자 다운로드는 워터마크 유지, 구독자만 제거 (코드와 일치)
- [ ] ⚠️ **워터마크 스펙 미세조정** (구현 vs 원래 명세, 디자인 확인 필요):
  - 위치: 코드는 **우측 상단**(`y: margin`), 명세는 우측 하단
  - 크기: 코드 **130px**, 명세 ~300px
  - 파일명 오타: `wartermark.png` (의도된 것인지 확인)

## 2. 템플릿 샘플 영상 + 재생 버튼

- [ ] **샘플 영상 5개 수령** ⏳ *유저 제공 대기 (세로형 권장, 용량 최적화)*
- [ ] 샘플 영상 5개를 앱 번들에 동봉 (`Resources/`에 추가)
- [ ] `VideoTemplate`에 샘플 영상 참조 필드 추가
- [ ] `TemplateGalleryScreen` 아이템에 ▶︎ 재생 버튼 추가
- [ ] 탭 시 전체화면 모달 + 자동재생 (AVPlayer / VideoPlayer), 닫기 처리

## 3. Google AdMob 보상형 광고 — ✅ 거의 완료 (실 App ID만 남음)

- [x] Google Mobile Ads SDK 통합 — SPM `swift-package-manager-google-mobile-ads` 12.14.0 + UMP 3.1.0 (`Package.resolved`)
- [x] `RewardedAdService` 프로토콜 + `AdMobRewardedAdService` + `NoOpRewardedAdService` 구현 (`Services/RewardedAdService.swift`)
- [x] ATT 동의 팝업 — `auto_photosApp.swift`에서 `ATTrackingManager.requestTrackingAuthorization()` 호출 + `NSUserTrackingUsageDescription` 설정됨
- [x] 저장 흐름 연동 — `saveWithRewardedAd()`, 세션 내 재저장 캐싱(`adRewardedForCurrentPreview`), 구독자/무료는 광고 없음
- [x] 광고 로드 실패/미수신·미시청 시 — **페이월 표시 + 다운로드 차단** (정책 확정: 광고/구독 없이는 다운로드 불가)
- [ ] ⚠️ **실 AdMob App ID 수령/설정** — Release `INFOPLIST_KEY_GADApplicationIdentifier`가 아직 `REPLACE_WITH_REAL_ADMOB_APP_ID` 플레이스홀더 (DEBUG는 구글 테스트 ID)
  - Release 광고단위 ID는 코드에 `ca-app-pub-9549021857234311/1031203180`로 들어가 있음 → 실 ID 맞는지 확인 필요

## 4. 애플 결제 (StoreKit 2) — 주간 $1.99 단일

- [ ] App Store Connect에 자동갱신 구독 상품 등록: `soya.auto-photos.weekly`, $1.99/주, 체험 없음
- [x] `SubscriptionService` 프로토콜 + `StoreKitSubscriptionService` 구현 (`isSubscribed`, 구매, 복원, 트랜잭션 감시)
- [x] Paywall 화면 구현 + 프리미엄 템플릿 선택 시 표시
  - 혜택 표기: 프리미엄 템플릿 / 워터마크 제거 / 광고 없이 저장
- [x] **복원(Restore Purchases) 버튼** 포함 (심사 필수)
- [x] StoreKit Configuration 파일 추가 (`auto-photos.storekit`) — Xcode 스킴에 연결 필요
  - Xcode → Edit Scheme → Run → Options → StoreKit Configuration → `auto-photos.storekit` 선택
- [x] 구독 상태를 워터마크·광고·프리미엄 게이팅에 연결 — `saveGeneratedVideo()`에서 `isSubscribed`로 워터마크·광고 분기 완료
- [ ] App Store Connect 상품 등록 후 실기기 결제 테스트

## 5. 템플릿 정리 + 신규 1개 추가

- [x] `TemplateCatalog.templates`에서 `restaurantShortForm`, `allPhotosFlow` 제거
- [x] `VideoTemplate`에 `isPremium` 구분 신규 추가
- [x] `lockScreenLog`, `lifeInFraems`를 프리미엄으로 지정
- [x] 갤러리 UI에 프리미엄 배지(PRO) 표시
- [ ] **새 무료 템플릿 1개 추가** (컨셉 미정 — 추후 브레인스토밍)
  - `VideoTemplate` static 정의 + `TemplateCatalog`에 등록 + 샘플영상
  - ⚠️ 현재 `TemplateCatalog.templates`는 **3개뿐**: `restaurantRecommendation`(무료) / `lockScreenLog`(PRO) / `lifeInFraems`(PRO)
  - → 현재 무료 1 / 프리미엄 2 구성. 계획(무료 3 / 프리미엄 2 = 5)과 다름 → 무료 템플릿 추가 필요

## 6. 테스트

- [ ] 전체 유닛 테스트 통과 (`xcodebuild test ... -scheme auto-photos`)
- [ ] 기존 테스트 중 제거/프리미엄 변경으로 깨지는 케이스 수정 (예: `homeExperienceUsesOnlyBuiltInTemplates`)
- [ ] 결제 테스트: StoreKit Configuration으로 구매 → 프리미엄 잠금 해제 / 복원 동작
- [ ] **워터마크 제거 테스트**: 구독 시 워터마크 사라지는지
- [ ] **AdMob 테스트**: 광고 시청 후 프리미엄 영상 다운로드 / 미시청 시 차단
- [ ] 무료 영상 저장(광고·워터마크 동작) end-to-end 확인

## 7. 애플 심사 제출

- [ ] 개인정보처리방침 URL 준비 (사진 접근·광고 추적·구독 명시)
- [ ] ATT 사용 목적 문구, 구독 약관 표기
- [ ] 스크린샷 / 앱 설명 / 키워드
- [ ] 구독·광고 심사 노트 작성 (테스트 계정·동작 설명)
- [ ] 앱 아이콘·버전·빌드 번호 최종 확인 후 제출

---

## 유저 제공 대기 항목 (⏳)

1. ~~워터마크 로고 PNG~~ ✅ 수령 완료 (`wartermark.png`)
2. 샘플 영상 5개 — 미수령
3. AdMob **실 App ID** (Release `GADApplicationIdentifier` 플레이스홀더) — 광고단위 ID는 코드에 있음(확인 필요)
4. 새 무료 템플릿 컨셉 결정
5. Apple Developer Program 등록 확인
