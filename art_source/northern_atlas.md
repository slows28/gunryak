# 북벌 전역도

`assets/art/northern_theater.webp`는 경도 103.00°E–110.00°E, 위도 32.98°N–35.14°N의 지형 음영과 하천을 두 배 해상도로 구운 지도다. 북쪽이 위이며 중앙 위도에서 동서·남북의 축척을 맞췄다. 왼쪽 아래의 중국 윤곽 안에 같은 범위를 표시했다. 게임은 지도 파일을 오프라인으로 읽는다.

- 원 지형 음영은 Basemap의 `basemap-data==2.0.0` 배포본 안에 있는 `mpl_toolkits/basemap_data/shadedrelief.jpg`이다. 세계 음영도 해상도는 10800×5400(2분각)이다. 해당 이미지의 배포 라이선스를 동봉했다. [Basemap 데이터](https://pypi.org/project/basemap-data/2.0.0/) · [이용 조건](Basemap-LICENSE.txt)
- 강줄기는 Natural Earth의 1:10m Rivers + Lake Centerlines, 위치 삽도의 윤곽은 1:110m Admin 0 Countries를 사용했다. Natural Earth의 자료는 퍼블릭 도메인이다. [하천 원본](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_10m_rivers_lake_centerlines.geojson) · [윤곽 원본](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_110m_admin_0_countries.geojson)

`python art_source/render_northern_atlas.py shadedrelief.jpg rivers.geojson countries.geojson`으로 다시 생성한다. Pillow와 NumPy가 필요하다. 지도 범위와 크기는 `scripts/northern_atlas.gd`에서 읽는다. 런타임의 장별 표식도 같은 좌표 변환을 사용한다.

전장 좌표는 가상 북벌 시나리오의 지역 대표점이다. 기산은 감숙 예현 동쪽 기산 일대, 천수는 기현(현재의 감곡) 일대, 상규는 현재 천수 시가지 일대에 잡았다. 기곡·가정은 각각 한중 북쪽 계곡과 진안현 용성진 일대, 농서는 현재 농서현을 기준으로 한다. 위수 도하점은 양릉 부근의 지도상 물길에 놓았고, 장안은 현대 서안 중심에서 북서쪽으로 떨어진 한대 장안성 일대에 놓았다. 번호와 연결선은 캠페인의 전개 순서를 뜻한다. 고대 도로와 각 전투의 정확한 교전 위치는 추정 범위가 넓다.

메인 메뉴의 `assets/art/title_art.webp`는 제갈량의 윤건·학창의·깃털 부채를 소재로 이 게임용으로 생성한 초상화다.
