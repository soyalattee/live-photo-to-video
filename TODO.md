# 런칭까지 남은 작업 (TODO)

> auto-photos iOS 앱 앱스토어 런칭 계획. 결정된 설계 기준 작업 목록.
> 작성일: 2026-05-30 / 번들 ID: `soya.auto-photos` / 배포 타겟: iOS 16.0

## 확정된 핵심 결정 사항

- **결제**: 주간 $1.99 단일 구독, 무료체험·연간 없음. Product ID `soya.auto-photos.weekly` (StoreKit 2)
- **광고**: AdMob 보상형. 프리미엄 영상 저장 시 광고 1회 시청 → 다운로드. (24시간 제한 정책 폐기, "볼 때마다" 다운로드)
- **워터마크**: 받을 로고 PNG(투명배경)를 반투명 적용. **무료 저장 시에만** 표시, 구독자·광고시청 저장 시 제거
- **템플릿 구성**: 무료 3 / 프리미엄 2 = 총 5개
  - 무료: `restaurantRecommendation`(오늘의 픽), 새 템플릿(컨셉 미정)
  - 프리미엄: `lockScreenLog`, `lifeInFraems`
  - 목록에서 제거: `restaurantShortForm`(추천 릴스), `allPhotosFlow`

---

## 0. 선결 / 블로킹 항목

- [ ] **Apple Developer Program 등록 상태 확인** ($99/년). 미등록 시 실기기 테스트·StoreKit 실거래·AdMob·심사 전부 불가
  - 주의: `project.pbxproj`에 `DEVELOPMENT_TEAM = LR5K2G2WSV`가 이미 박혀 있음 → 실제 등록 여부 확인 필요
- [ ] 같은 폴더에서 동시 실행 중인 다른 Claude/에디터 세션 종료 (파일 충돌·임시디스크 문제 방지)
- [ ] 빌드/테스트용 임시 디스크 공간 확보 (`CLAUDE_CODE_TMPDIR` 여유 경로 지정 검토)

---

## 1. 워터마크 변경

- [ ] **로고 워터마크 이미지(PNG, 투명배경) 수령** ⏳ *유저 제공 대기*
- [ ] 로고 에셋을 `Resources/Brand/`에 추가하고 에셋 카탈로그/번들에 등록
- [ ] `DefaultVideoGenerationService` 렌더 파이프라인에 워터마크 오버레이 레이어 신규 추가
  - 위치: 우측 하단 / 불투명도 ~40% / 폭 1080px 기준 ~300px
- [ ] 워터마크 적용 조건 로직: 무료 저장 시에만 ON, 구독자·광고시청 저장 시 OFF
  - `VideoRenderOptions` 또는 저장 경로에 워터마크 플래그 전달
- [ ] 렌더 캐시가 워터마크 유무를 구분하도록 캐시 키 갱신 (toggle 시 재인코딩 정확성)

## 2. 템플릿 샘플 영상 + 재생 버튼

- [ ] **샘플 영상 5개 수령** ⏳ *유저 제공 대기 (세로형 권장, 용량 최적화)*
- [ ] 샘플 영상 5개를 앱 번들에 동봉 (`Resources/`에 추가)
- [ ] `VideoTemplate`에 샘플 영상 참조 필드 추가
- [ ] `TemplateGalleryScreen` 아이템에 ▶︎ 재생 버튼 추가
- [ ] 탭 시 전체화면 모달 + 자동재생 (AVPlayer / VideoPlayer), 닫기 처리

## 3. Google AdMob 보상형 광고

- [ ] **AdMob 계정/앱 생성 → App ID + Rewarded 광고단위 ID 수령** ⏳ *유저 제공 대기 (개발은 구글 테스트 ID로 진행)*
- [ ] Google Mobile Ads SDK 통합 (SPM 권장) + `GADApplicationIdentifier` Info.plist 설정
- [ ] `RewardedAdService` 프로토콜 + `AdMobRewardedAdService` 구현 / 테스트용 `NoOpRewardedAdService`
- [ ] ATT(App Tracking Transparency) 동의 팝업 + `NSUserTrackingUsageDescription` 설정
- [ ] 저장 흐름 연동:
  - 프리미엄 영상 저장 → 광고 시청 → 콜백에서 다운로드
  - 동일 결과물은 세션 내 재저장 시 광고 생략 (가벼운 캐싱)
  - 구독자·무료 영상은 광고 없이 저장
- [ ] 광고 로드 실패/미수신 시 폴백 처리 (저장 막힘 방지 UX)

## 4. 애플 결제 (StoreKit 2) — 주간 $1.99 단일

- [ ] App Store Connect에 자동갱신 구독 상품 등록: `soya.auto-photos.weekly`, $1.99/주, 체험 없음
- [x] `SubscriptionService` 프로토콜 + `StoreKitSubscriptionService` 구현 (`isSubscribed`, 구매, 복원, 트랜잭션 감시)
- [x] Paywall 화면 구현 + 프리미엄 템플릿 선택 시 표시
  - 혜택 표기: 프리미엄 템플릿 / 워터마크 제거 / 광고 없이 저장
- [x] **복원(Restore Purchases) 버튼** 포함 (심사 필수)
- [x] StoreKit Configuration 파일 추가 (`auto-photos.storekit`) — Xcode 스킴에 연결 필요
  - Xcode → Edit Scheme → Run → Options → StoreKit Configuration → `auto-photos.storekit` 선택
- [ ] 구독 상태를 워터마크·광고·프리미엄 게이팅에 연결 (워터마크 구현 후)
- [ ] App Store Connect 상품 등록 후 실기기 결제 테스트

## 5. 템플릿 정리 + 신규 1개 추가

- [x] `TemplateCatalog.templates`에서 `restaurantShortForm`, `allPhotosFlow` 제거
- [x] `VideoTemplate`에 `isPremium` 구분 신규 추가
- [x] `lockScreenLog`, `lifeInFraems`를 프리미엄으로 지정
- [x] 갤러리 UI에 프리미엄 배지(PRO) 표시
- [ ] **새 무료 템플릿 1개 추가** (컨셉 미정 — 추후 브레인스토밍)
  - `VideoTemplate` static 정의 + `TemplateCatalog`에 등록 + 샘플영상

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

1. 워터마크 로고 PNG (투명배경)
2. 샘플 영상 5개
3. AdMob App ID + Rewarded 광고단위 ID
4. 새 템플릿 컨셉 결정
5. Apple Developer Program 등록 확인
