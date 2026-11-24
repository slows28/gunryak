# 군략 전쟁 엔진 — 자동 실행 환경

## 권장 엔진
Godot **4.7.2 Stable**, 일반 GDScript 에디터(Linux/Windows x86_64).

## 자동 시험
프로젝트 루트에서:

```bash
python3 tools_run_engine_tests.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64
```

이 도구는 버전 확인 뒤 실제 Godot을 세 번 실행합니다.

1. 에디터의 프로젝트 가져오기 및 스크립트 파싱
2. 6개 시드 반복 전투·보급·전령·책사 포획 검증 (`tests/smoke.gd`)
3. 메인 장면 생성 및 180프레임 진행 (`tests/scene_smoke.gd`)

**중요:** 테스트 스크립트가 있다는 사실만으로 통과한 것이 아닙니다. `test_results/engine_test_report.json`의 `status: "PASSED"`와 3개 검사 결과가 있어야만 실제 Godot 검증을 완료했다고 기록합니다. `NOT_RUN`은 통과가 아닙니다.

### GitHub Actions 연동
`.github/workflows/godot-tests.yml`은 GitHub 저장소로 푸시할 때 공식 Godot 4.7.2 Linux x86_64 실행 파일을 다운로드하고 위 테스트를 수행하도록 작성한 CI 정의입니다.

**CI는 현재 환경에서 실행된 적이 없습니다.** 작업 컨테이너의 외부 DNS 접근이 차단되어 Godot 바이너리 설치가 실패했고, `.github/workflows` 파일을 만들었다고 GitHub에서 자동 실행되는 것은 아닙니다. GitHub 저장소에 올려야 활성화됩니다.

### 크래시 진단 한계
Headless Linux 테스트 통과는 Windows 렌더링/드라이버의 강제 종료를 재현하지 못할 수 있습니다. Windows 테스트 또는 크래시 로그 확인이 별도로 필요합니다.

### GitHub 연결 상태
현재 연결 계정에 사용 가능한 저장소가 0개이며 GitHub App 설치 정보도 반환되지 않았습니다. 저장소 생성 및 연동 앱에 대한 저장소 접근 승인 이후에만 워크플로 실행이 가능합니다. 공식 SHA256 값을 현재 환경에서 검증하지 못해 잘못된 해시 검증 줄은 제거했습니다.
