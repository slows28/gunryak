# 군략 (Gunryak) — Godot 전쟁 시뮬레이션

v0.5.1 개발·회귀 테스트 단계입니다. Godot 4.7.2 프로젝트는 루트 project.godot으로 열 수 있습니다.

## 핵심 시스템
- 세 병과(보병, 궁병, 기병), 진형, 장수 성향별 자동 전술 판단
- 별도 보급기지 및 보급 손실, 5턴 시작 시 작전 지도에서 전령 파견
- 책사 위치 및 포획 판정
- GitHub Actions에서 Linux / Windows Godot headless 회귀 테스트 자동 실행

## 검증
- tests/smoke.gd: 36개 전투 조건, 16개 임무·진형 조합, 습격·시야·보급·전령·책사 검증
- tests/scene_smoke.gd: 실제 메인 장면에서 한 전투 종료까지 반복
- tools_run_engine_tests.py: Godot 4.7.2로 프로젝트 import, 시뮬레이션, 장면 검사

이 릴리스의 CI 결과를 확인하기 전까지 엔진 실행 검증 완료를 주장하지 않습니다.
Windows에서 발생했던 게임 창 강제 종료의 원인은 아직 확인되지 않았습니다.
