# 군략 — 개발 진행 현황 및 보고 원칙

> 최종 갱신: 2026-11-25 (KST). 구현/검증 상태는 실제 GitHub Actions 증거를 기준으로 기록합니다.

## 협업 원칙 — 확정

1. **한 번에 하나씩** 개발 항목을 선정하고, 구현 → 자동 검사 → 실패 수정 → 승인 가능한 결과 보고 후 다음 항목으로 넘어갑니다.
2. **각 단계마다 진행 현황과 실제 이미지**를 함께 제공합니다. 우선순위는 실제 Godot 화면 캡처/전후 비교입니다. 설계도·목업·일러스트는 구현 화면과 명확히 구분합니다.
3. 진행 보고에 반드시 포함할 항목은 목표, 작업 내용, 현재 상태(구현·검증·완료 분리), GitHub 테스트 링크, 게임 화면 이미지, 남은 문제, 다음 단일 작업, 사용자에게 필요한 행동(없으면 없음)입니다.
4. 작업 브랜치에서 변경하고 **Godot 4.7.2 Linux + Windows 자동 테스트**를 통과한 뒤 기본 브랜치에 반영합니다. 테스트 미실행·실패는 절대로 완료로 표기하지 않습니다.
5. **사용자에게 반복 ZIP 업로드·삭제·재설치를 요구하지 않습니다.** 가능한 코드 수정·커밋·CI 확인은 ChatGPT에서 GitHub 연결을 통해 처리합니다.
6. 실제 UI에서 발생한 Windows 강제 종료는 headless 자동 테스트만으로 해결되었다고 판정하지 않습니다.
7. 계획·결정·검증 결과는 이 파일 및 노션 [군략 기획·개발 기록](https://app.notion.com/p/421bbdff912281c9baaaffad2c768e55)에도 기록합니다.
8. 이미지가 아직 없으면 "미확보"라고 표시하고, 캡처 확보를 우선 개발 작업으로 삼습니다. 게임 구현을 대표하지 않는 가짜 스크린샷은 제출하지 않습니다.

## 현재 기준선

| 단계 | 과업 | 상태 | 근거·산출물 |
|---|---|---|---|
| P0 | GitHub + Linux/Windows Godot 자동 테스트 구축 | **완료** | [v0.5.1 CI 성공](https://github.com/slows28/gunryak/actions/runs/45515195186), commit `a7aef99d39c553e10c7595c1afd0e173df688861` |
| P1 | 실제 게임 화면 자동 캡처 및 개발 보고 이미지 확보 | **완료** | [실제 스크린샷 CI 성공](https://github.com/slows28/gunryak/actions/runs/45515800259) |
| P2 | 한글 글리프 렌더링 오류 수정 | **완료** | [Linux 실제 캡처 + Windows 엔진 CI 통과](https://github.com/slows28/gunryak/actions/runs/45516570429) |
| P3 | 궁병 근접 위협 회피 및 실제 후방 이동 | **완료** | [Linux·Windows 회귀검증 및 28초 이미지](https://github.com/slows28/gunryak/actions/runs/45516915453) |
| P4 | Windows GUI 강제 종료 재현/안정성 검사 | **미완료** | 과거 약 3초 크래시 미해결 검증 |
| M1 | **실제 진형 슬롯 기반 전열 접촉 전투 + 화면 가독성** | **완료** | [Linux·Windows 회귀검증 + 3장 실화면](https://github.com/slows28/gunryak/actions/runs/45521133790) |

_단계 전체 완료율은 임의의 퍼센트로 제시하지 않으며, 검증된 게이트 수로 표시합니다._

## 현재 개발 스냅샷

- **현재 버전:** v0.5.1
- **저장소:** https://github.com/slows28/gunryak
- **실제 엔진 검사:** Godot 4.7.2 Linux 및 Windows headless, import / simulation / scene 테스트 통과
- **게임 화면 이미지:** [M1 실제 PNG 3장](https://github.com/slows28/gunryak/actions/runs/45521133790/artifacts/14980390934): 전투 준비 / 12초 / 28초 경과 (각 1280×800, Linux Godot 그래픽 렌더링)
- **남은 중요한 검증:** Windows GUI 게임 창 강제 종료 문제의 재현 및 원인 확인
- **다음 단일 개발 과제:** M2 - 부대 간 겹침·돌파·전선 고착을 물리적으로 분리하는 전투 기동 시스템. Windows GUI 강제 종료 재현 문제(P4)는 여전히 미완료.

## 단계별 보고 템플릿

### [P번호] 개발 항목

**진행 현황:** [구현/검증 중/완료]  
**변경된 기능:** ...  
**검증 결과:** Linux ... / Windows ... / GUI ...  
**증거 이미지:** 실제 게임 화면 링크·캡처 (없으면 미확보)  
**미해결 항목:** ...  
**다음 한 단계:** ...  
**사용자 작업:** 없음 / 실제로 필요한 단 하나의 작업 명시


## P1 증거 및 시각 검수 (2026-11-25)

- 코드 커밋: [890a1e50](https://github.com/slows28/gunryak/commit/890a1e50ee2f77bc612f3a54cb3cd3e0bfa6b47e)
- Godot 4.7.2 Linux Xvfb + OpenGL 실제 렌더링: before_battle.png (1280×800, 41681 bytes), battle_12s.png (1280×800, 44129 bytes)
- [스크린샷 ZIP 다운로드 (GitHub Actions)](https://github.com/slows28/gunryak/actions/runs/45515800259/artifacts/14976784530)
- [Linux·Windows CI 성공 기록](https://github.com/slows28/gunryak/actions/runs/45515800259)
- **시각 검수로 발견한 문제:** 한글 텍스트가 네모로 출력됨. 현재 시제품은 화면 구성/전투 병력·진형 위치가 확인되지만 정상적인 한글 UI라고 볼 수 없음.
- 다음 단일 작업 P2에서 한글 폰트 대체/표시 문제를 해결하고 동등한 실제 게임 PNG를 다시 비교한다.

## P2 완료 — 한글 렌더링 오류 (2026-11-25)

- 코드 커밋: [ea9d734f](https://github.com/slows28/gunryak/commit/ea9d734f2d4cf79aa6b18e9812b503fb537d12af)
- 시스템 한국어 폰트 `SystemFont` 및 루트 UI `Theme` 기본 폰트를 적용했고, 전장 지도 텍스트의 `draw_string`도 같은 폰트로 교체.
- Linux 이미지 CI에 `fonts-nanum` 설치 및 글리프 `군략` 존재 검사 추가.
- [실제 테스트 성공](https://github.com/slows28/gunryak/actions/runs/45516570429), [실제 PNG 2장](https://github.com/slows28/gunryak/actions/runs/45516570429/artifacts/14977697613).
- 이미지에서 제목, 버튼, 장수 이름과 전황 텍스트가 정상 한글로 출력된 것을 육안 확인. 다만 시스템폰트 기반이므로 한국어 글꼴이 없는 플랫폼의 표시를 보장할 수 없으며, 향후 번들 폰트 검토 필요.

## P3 완료 — 궁병의 실제 근접 위협 회피 (2026-11-25)

- 코드 커밋: [b35141ff](https://github.com/slows28/gunryak/commit/b35141ff20d773498d20cf718c8d7c71cd51f382)
- 실제 관측된 적이 110 거리 안으로 접근하면 궁병이 적 반대 방향으로 이동 목표를 설정함. 이전의 제자리 정지 명령으로 이동 목표가 덮이는 결함 수정. 위협이 사라지면 원래 작전 복귀.
- `tests/smoke.gd`에 궁병 관측 기반 회피 선택·이동 후 실제 거리 증가·상태 보전·작전 복귀 검사를 추가.
- [Linux·Windows Godot 4.7.2 CI 모두 성공](https://github.com/slows28/gunryak/actions/runs/45516915453), [전투 28초 실제 이미지 포함 PNG 3장](https://github.com/slows28/gunryak/actions/runs/45516915453/artifacts/14977509979).
- 기능 검증과 실제 플레이 전술 품질 평가는 별개: 궁병은 아직 개별 병사 단위 AI나 엄폐·군집 충돌 모델을 사용하지 않음. Windows 실제 창에서 과거 강제 종료 해결 여부 미확인.

## M1 완료 — 실제 병력 배치와 전열 접촉 전투 (2026-11-25)

- 근거 커밋: `1aae5fdadeaea4186f84f8fe9e6db94f182230d0` 초기 구현 후 접촉 테스트 실패를 로그로 재현. `2485e642e739759714f7cf3c7e8d05672374bf6d` 및 `a2968a4b8f7ba3ff64ecef0f8df7c648eab9936d`에서 접촉 피해 계수/테스트 기하 조건을 수정.
- 게임 엔진 `formation_slots()`: **횡대 6×2 / 종대 3×4 / 방진 4×3**의 대표 병력 12개 위치를 한 가지 코드로 산출; 실제 전투 접촉 계산과 화면 렌더링이 같은 슬롯을 사용.
- `formation_contacts()`: 적 병사 슬롯과 공격 병사 슬롯의 실제 거리로 전열에 닿는 병사 수 계산. 근접 피해에 접촉 전열 규모를 반영.
- 기병 돌격 시 방진 접촉 피해 억제, 종대의 측후면 노출, 궁병 근거리 약화 및 숲 엄폐에 따른 피해 감소 적용.
- 보병(사각형), 궁병(삼각형), 기병(원형)으로 화면상 구별. 장수 이름표 충돌 방지용 라벨 위치 분리 및 선택 부대 전열 접촉 수 HUD 표기.
- 자동 회귀 검사: 횡대/종대의 실제 접촉 병사 수와 피해 차이, 방진의 기병 돌격 방어, 상태 불변식. **초기 테스트 244항목 중 1항목 실패 → 수정 → Linux·Windows CI 모두 PASS**.
- [검증된 CI run](https://github.com/slows28/gunryak/actions/runs/45521133790): Linux 및 Windows Godot 4.7.2 프로젝트 파싱/전투 시뮬레이션/장면 검사 성공, Linux Xvfb 실제 게임 화면 준비·12초·28초 PNG 생성.
- [실제 이미지 아티팩트](https://github.com/slows28/gunryak/actions/runs/45521133790/artifacts/14980390934) / GitHub 기본 main 반영 완료.
- **한계:** 표시용 12개 대표점으로 계산하는 부대 모델이며, 개별 병사들의 독립 경로·피격·충돌을 구현한 것은 아니다. 부대 자체 충돌 차단, 3D 물리, 복잡한 포위, Windows 실창 크래시 재현은 아직 해결되지 않았다.
- **다음 게임 개발 범위:** M2 부대 겹침 방지 및 서로 밀리는 실제 전선(충돌·후퇴·돌파), 일관된 전투 목표·형성 유지.
