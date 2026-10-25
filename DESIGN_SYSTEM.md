# 디자인 시스템 — 코치조의 ALPHA 육성 센터

> 투두메이트(todo mate) 디자인을 분석해 뽑은 시각 규칙과, 이 앱(macOS 26 · Liquid Glass)에 적용하는 방법을 정리한 문서.
> 코드의 단일 출처는 [`Sources/Shared/DesignSystem.swift`](Sources/Shared/DesignSystem.swift)이며, 이 문서의 토큰 이름과 1:1로 대응한다.

| 항목 | 내용 |
| --- | --- |
| 기준 자료 | App Store의 「투두메이트 for desktop」(Mac) 스크린샷 4장, 「투두메이트: 할 일」(iOS) 스크린샷 6장 |
| 측정 방법 | 2880×1800 원본 스크린샷에서 영역별 픽셀 색 히스토그램을 뽑아 대표색을 확정 |
| 문서 버전 | v1.0 (2026.10.23) |

---

## 1. 원칙

1. **흰 여백이 곧 구조다.** 카드 그림자, 테두리, 격자선을 쓰지 않는다. 묶음은 간격과 옅은 회색 서피스(`surface`)로만 나눈다.
2. **색은 목표(카테고리)만 가진다.** 화면의 거의 모든 요소는 무채색(`text` / `textSecondary` / `surface` / `checkOff`)이고, 채도 있는 색은 목표 색·요일 색에만 쓴다.
3. **작은 글자, 굵은 제목.** 본문은 13–14pt Regular, 제목과 목표 이름은 Bold. 중간 굵기는 거의 쓰지 않는다.
4. **선택은 검정.** 선택한 날짜, 선택한 탭/필, 주요 버튼은 `ink`(라이트 `#121212`, 다크 흰색)로 칠한다. 강조색(accent) 기본값도 검정이다.
5. **Glass는 조작 레이어에만.** (이 앱 고유 규칙) 사이드바, 툴바, 이전/다음 같은 이동 버튼, 타이머 컨트롤, 메뉴 막대 컨트롤은 Liquid Glass를 유지한다. 할 일 목록, 달력 칸, 칩, 체크박스 같은 **콘텐츠는 불투명한 투두메이트 스타일**로 그린다.

---

## 2. 컬러

### 2.1 중립색

| 토큰 | 라이트 | 다크 | 쓰임 | 측정 근거 |
| --- | --- | --- | --- | --- |
| `DS.bg` | `#FFFFFF` | `#000000` | 콘텐츠 배경 | 앱 본문 |
| `DS.text` | `#121212` | `#F2F2F2` | 본문·제목 텍스트 | 할 일 제목, 날짜 숫자 |
| `DS.textSecondary` | `#8B919B` | `#8E8E93` | 상태 문구, 부제 | 프로필 한 줄 소개 |
| `DS.surface` | `#F2F2F2` | `#1C1C1E` | 목표 칩, 필, 원형 버튼, 입력칸 | 목표 칩·친구 필 배경 |
| `DS.checkOff` | `#D5D9DC` | `#3A3A3C` | 미완료 체크박스, 빈 날짜 도장, 빈 점 | 미완료 체크박스 |
| `DS.divider` | `#EEEEEE` | `#2C2C2E` | 가는 구분선(0.5pt) | 목록 하단 구분선 |
| `DS.ink` | `#121212` | `#FFFFFF` | 선택 원, 선택 필, 주요 버튼 | 선택 날짜 원, 선택된 프로필 필 |
| `DS.onInk` | `#FFFFFF` | `#121212` | `ink` 위의 글자 | |

### 2.2 요일색

| 토큰 | 값 | 쓰임 |
| --- | --- | --- |
| `DS.sunday` | `#FF4A4A` | 일요일 라벨과 날짜 숫자 |
| `DS.saturday` | `#007AFF` | 토요일 라벨과 날짜 숫자 |

### 2.3 목표 팔레트 (`Palette`, 10색)

투두메이트 목표 색은 **채도 높은 단색**이다(측정: 보라 `#6236FF`, 남색 `#454DFF`, 분홍 `#FF2C9E`, 검정 `#121212`). 저장된 `colorIndex`(0–9)와 호환되도록 개수와 순서를 유지한다.

| 인덱스 | 이름 | 값 |
| --- | --- | --- |
| 0 | 빨강 | `#FF4A4A` |
| 1 | 주황 | `#FF8A1F` |
| 2 | 노랑 | `#FFBE0B` |
| 3 | 초록 | `#20C063` |
| 4 | 청록 | `#00B4C5` |
| 5 | 파랑 | `#007AFF` |
| 6 | 남색 | `#454DFF` |
| 7 | 보라 | `#6236FF` |
| 8 | 분홍 | `#FF2C9E` |
| 9 | 검정 | `DS.ink` — `#121212` (다크: 흰색) |

- 목표 색은 **글자색(칩 이름)과 채움(체크박스·일정 막대·점)** 두 가지로만 쓴다. 투명도를 낮춘 "연한 배경"은 쓰지 않는다. (예외: 드래그 대상 강조 8%)
- 채움 위의 글자·아이콘은 항상 흰색(검정 목표는 `onInk`).

### 2.4 포모도로 세션 색

| 세션 | 색 |
| --- | --- |
| 집중 | `ink` (투두메이트 타이머처럼 흑백) |
| 짧은 휴식 | 초록(3) |
| 긴 휴식 | 파랑(5) |

---

## 3. 타이포그래피

서체는 설정에서 고른 앱 서체(`appFont`)를 그대로 쓰고, 크기·굵기만 아래 스케일로 고정한다. 투두메이트는 Pretendard 계열의 깔끔한 고딕 느낌이다.

| 토큰 (`DS.TextSize`) | 크기 | 굵기 | 쓰임 |
| --- | --- | --- | --- |
| `display` | 72 | Bold | 타이머 숫자 (고정폭 숫자) |
| `title` | 22 | Bold | 화면 제목 |
| `headline` | 15 | Bold | 프로필 이름, "2026년 7월", 섹션 제목 |
| `body` | 14 | Regular | 할 일 제목, 일정 제목 |
| `chip` | 13 | Bold | 목표 칩 이름 |
| `caption` | 12 | Regular | 부제, 개수, 메모 |
| `label` | 11 | Medium | 요일 라벨, 날짜 숫자(작은 달력) |
| `micro` | 10 | Medium | 일정 막대, 도장 안 숫자 |

---

## 4. 간격 · 반경 · 크기

| 토큰 | 값 | 쓰임 |
| --- | --- | --- |
| `DS.Space.xxs` | 4 | 아이콘–글자 |
| `DS.Space.xs` | 8 | 행 안 요소 간격 |
| `DS.Space.s` | 12 | 할 일 행 사이(세로 패딩 6×2) |
| `DS.Space.m` | 16 | 목표 섹션 안쪽 |
| `DS.Space.l` | 24 | 목표 섹션 사이, 화면 여백 |
| `DS.Space.xl` | 32 | 2단 레이아웃 기둥 사이 |
| `DS.Radius.checkbox` | 5 | 18pt 체크박스 |
| `DS.Radius.bar` | 3 | 일정 막대 |
| `DS.Radius.tile` | 14 | 액션 타일, 통계 카드 |
| `DS.Radius.card` | 18 | 일기 카드, 위젯 안 카드 |
| `DS.Size.checkbox` | 18 | 기본 체크박스 (위젯·메뉴 막대 15) |
| `DS.Size.stamp` | 22 | 날짜 도장 |
| `DS.Size.circleButton` | 28 | 원형 이동 버튼 |
| 칩·필 | 캡슐 | 높이 28 |

---

## 5. 컴포넌트

### 5.1 체크박스 `TodoCheckbox`
- 18×18 둥근 사각형(반경 5).
- 미완료: `checkOff` 채움, 테두리 없음.
- 완료: 목표 색 채움 + 흰 `checkmark`(굵기 heavy, 크기 0.55×).
- 체크 시 스프링(0.3s, 감쇠 0.55)으로 채움이 0.6 → 1.0 확대.

### 5.2 목표 칩 `GoalChip`
- `surface` 캡슐, 좌우 패딩 10, 높이 28.
- 구성: 아이콘(SF Symbol, `textSecondary`, 11pt) → 목표 이름(`chip`, 목표 색) → `+`(12pt Bold, `text`).
- 칩 전체가 "이 목표에 할 일 추가" 버튼. 드래그하면 목표 순서 변경.

### 5.3 날짜 도장 `DayStamp`
투두메이트 달력의 "날짜 위 아이콘". 그날의 할 일 상태를 보여 준다.

| 상태 | 모양 |
| --- | --- |
| 할 일 없음 | `checkOff` 둥근 사각형 (옅게 50%) |
| 진행 중 | `checkOff` 채움 + 남은 개수(Bold, 절반 미만 완료면 `text`, 이상이면 흰색) |
| 모두 완료 | 강조색(기본 `ink`) 채움 + 흰 체크 |

반경은 크기의 30%. 진행 중 상태에서는 완료 비율만큼 아래에서부터 강조색이 차오른다.

### 5.4 날짜 숫자 `DateNumber`
- 기본: 평일 `text`, 일 `sunday`, 토 `saturday`. 다른 달 날짜는 40% 투명.
- 선택: 지름 22 `ink` 원 + `onInk` 숫자(Bold).
- 오늘(선택 아님): Bold + 아래 2pt 점.

### 5.5 원형 버튼 `CircleIconButton`
- 지름 28, `chevron.left/right` 같은 단일 아이콘. Glass(`.glass`) 원형. (투두메이트는 `surface` 원 — 이 앱은 조작 레이어이므로 Glass)

### 5.6 필 토글 `PillToggle`
- "주 / 월", "1주 / 1개월" 같은 2–3개 선택지. 선택된 항목만 `ink` 캡슐 + `onInk` 글자, 나머지는 `surface` 캡슐.

### 5.7 일정 막대 `EventBar`
- 목표/일정 색으로 꽉 찬 사각형(반경 3), 흰 `micro` 글자 1줄, 높이 14.
- 시간 일정도 같은 모양(앞에 시각). 타임라인 블록도 꽉 찬 색 + 흰 글씨.

### 5.8 액션 시트 (`TodoRow` 팝오버) / `ActionTile`
- 할 일 행 hover 시 오른쪽에 `⋯` 버튼 → 팝오버.
- 맨 위에 할 일 제목(`headline`), 아래 3열 타일: 아이콘 20pt + 라벨 `caption`. 타일은 `surface` 채움, 반경 14, 높이 64.
- 위험 동작(삭제)은 아이콘·글자를 `sunday` 색으로.

### 5.9 점 격자 `DotGrid`
- 통계용. 지름 10 원을 7열로. 완료 = 목표 색, 그 외 = `checkOff`.
- 머리말: 목표 이름(목표 색, Bold) + ` / 총수`(`textSecondary`).

### 5.10 타이머 `TimerFace`
- 세션 이름(`headline`) → 0.5pt 구분선 → `display` 숫자 → 진행 막대(2pt, 구분선 자리에 왼쪽부터 세션 색이 차오름).
- 컨트롤: Glass 캡슐 안에 "원형 아이콘(지름 28) + 글자" (예: ⏸ 일시정지, ⏭ 건너뛰기). 주요 버튼은 `.glassProminent` + 세션 색.

### 5.11 일기 카드 `DailyNoteCard`
- 강조색이 아닌 **`ink` 바탕 + `onInk` 글자** 카드(반경 18). 기분 이모지는 32pt로 크게, 선택 안 된 이모지는 40% 투명.

### 5.12 화면 머리말 `ScreenHeader` / `ProfileHeader`
- 제목 `title`, 부제 `caption`·`textSecondary`. 투두 화면은 투두메이트 프로필 영역처럼 원형 앱 아이콘(지름 44) + 이름(`headline`) + 한 줄 상태.

---

## 6. 화면별 적용

| 화면 | 규칙 |
| --- | --- |
| 투두 | 창 너비 ≥ 900이면 2단: 왼쪽(폭 320) 프로필 머리말 + 달력, 오른쪽 목표 칩 + 할 일. 좁으면 1단. 달력은 `DayStamp` 위 + `DateNumber` 아래. 목표 섹션 사이 24, 할 일 행 높이 32. |
| 포모도로 | 링 없음. `TimerFace` 중앙 정렬, 아래 사이클(둥근 사각 점) → 연결된 할 일 → 통계(요약 타일 + 막대 차트 + 목표별 점 격자). |
| 캘린더 | 월간: 격자선 없음, 칸 위쪽 가운데 `DateNumber`, 아래 `EventBar` 최대 3개 + `+n`, 오른쪽 위 작은 `DayStamp`. 주/일: 꽉 찬 색 블록. 오른쪽 패널: 체크박스·막대. |
| 설정 | macOS 기본 Form 유지. 색 스와치는 둥근 사각형(반경 6), 선택 시 `ink` 테두리. |
| 시트 | 주요 버튼 `.glassProminent` + `ink` tint. 목표 미리보기는 `GoalChip`. |
| 메뉴 막대 | 머리말 "TODAY n"(Bold), 체크박스 15pt, 타이머는 굵은 숫자 + 진행 막대. |
| 위젯 | 흰 배경(다크 검정), "TODAY n" 머리말, 체크박스 목록(중·대 크기는 2열), 달력 위젯은 `DayStamp`/`DateNumber`, 포모도로는 굵은 숫자 + 진행 막대. |

---

## 7. 모션

| 상황 | 모션 |
| --- | --- |
| 체크 | `spring(response: 0.3, dampingFraction: 0.55)` 채움 확대 + 체크 등장 |
| 날짜 선택 | `snappy` — 선택 원이 이동(같은 `matchedGeometryEffect` 네임스페이스) |
| 할 일 추가/삭제 | `snappy` 삽입·제거 |
| 타이머 숫자 | `contentTransition(.numericText(countsDown: true))` |
| 타이머 컨트롤 | `GlassEffectContainer` + `glassEffectID` 모핑 (기존 유지) |

---

## 8. 접근성

- 체크박스·도장은 `accessibilityLabel`로 "완료/미완료", "n개 중 m개 완료"를 읽는다.
- 요일색만으로 정보를 전달하지 않는다(라벨 텍스트 병기).
- 투명도 줄이기 설정 시 Glass가 불투명해져도 `ink`/`surface` 대비가 유지된다.

---

## 9. 코드 대응표

| 문서 | Swift |
| --- | --- |
| 중립색·요일색 | `DS.bg`, `DS.text`, `DS.textSecondary`, `DS.surface`, `DS.checkOff`, `DS.divider`, `DS.ink`, `DS.onInk`, `DS.sunday`, `DS.saturday` |
| 타이포 | `DS.TextSize.*` + `.appFont(DS.TextSize.body)` |
| 간격·반경·크기 | `DS.Space.*`, `DS.Radius.*`, `DS.Size.*` |
| 목표 팔레트 | `Palette.colors`, `Palette.color(_:)` |
| 공용(앱·위젯) 컴포넌트 | `TodoCheckbox`, `DayStamp`, `DateNumber`, `EventBar`, `ProgressBar` — `Sources/Shared/DesignSystem.swift` |
| 앱 전용 컴포넌트 | `GoalChip`, `CircleIconButton`, `PillToggle`, `ActionTile`, `DotGrid`, `SectionTitle`, `WeekdayHeader` — `Sources/AlphaCenter/Views/Common/Components.swift` / `ProfileHeader` — `TodoView.swift` |
| 서체 전달 | 공용 컴포넌트는 `.dsFont()`로 환경값 `appFontResolver`를 읽는다 (앱: `AppFontResolver.app`, 위젯: `entry.fontResolver`). 강조색은 환경값 `dsAccent` |
