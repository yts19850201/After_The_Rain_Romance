# 자산 출처와 이용 조건

작성일: 2026-10-22. 실제 적용 파일은 `data/asset_list_261022.json`에도 기록했습니다. 이 문서는 특정 배포 플랫폼의 승인이나 판매 가능 여부를 확정하지 않습니다. 배포 정책과 제출 조건은 28단계에서 실제 콘텐츠를 기준으로 확인합니다.

## 배경과 서윤 그림

- 제작 도구: OpenAI 내장 `image_gen`.
- 배경: `art/cafe_rain_261022.png`, `art/cafe_evening_261022.png` / 각 1672×941.
- 인물: `art/seoyun_neutral_261022.png`, `art/seoyun_smile_261022.png`, `art/seoyun_thoughtful_261022.png`, `art/seoyun_shy_261022.png` / 각 1024×1536, 투명 배경.
- 이 프로젝트의 성인 캐릭터와 카페 설정을 프롬프트로 새로 생성했습니다. 특정 작가·기존 게임·브랜드를 참고 대상으로 지정하지 않았습니다. 저녁과 표정은 처음 생성한 자체 그림을 참조해 편집했습니다.
- 미소와 생각 표정은 가장자리 배경 제거를 한 차례 더 요청한 결과를 적용했습니다. 원본 생성 결과는 Codex 생성 이미지 폴더에 남겼습니다.
- 이용 조건: 생성 당시 사용한 OpenAI 서비스의 [이용약관](https://openai.com/policies/terms-of-use/) 및 적용되는 계정 계약을 따릅니다. 이 기록에서 별도의 CC0·독점 저작권·제3자 권리 보증을 부여하지 않습니다.
- 각 호출의 프롬프트와 참조 관계는 [생성 기록](art/GENERATION_PROMPTS_261022.md)에 있습니다. 요청에 따라 별도 ZIP은 만들지 않았습니다.

## 음악과 효과음

| 파일 | 내용 | 길이 |
|---|---|---|
| `audio/cafe_261022.wav` | 대화용 잔잔한 아르페지오와 화음 | 20초, 반복 |
| `audio/ending_261022.wav` | 엔딩용 아르페지오와 화음 | 20초, 반복 |
| `audio/confirm_261022.wav` | 대화 확인 | 약 0.15초 |
| `audio/select_261022.wav` | 선택 확정 | 약 0.34초 |
| `audio/transition_261022.wav` | 장면 전환 | 약 0.85초 |

원본: `tools/generate_audio_261022.gd`. 외부 음원·악보·샘플을 가져오지 않고 프로젝트에서 주파수, 음표 배열과 음량 곡선을 작성해 합성했습니다. 22,050Hz / 16bit / 모노 PCM WAV입니다. 각 파일의 최대 진폭은 약 0.72로 맞췄습니다. 음악의 양 끝 음량을 낮춰 반복 경계의 클릭 소리를 줄였습니다. 배경 음악 기본값은 -22dB, 효과음은 -18dB이며 개별 설정이 가능합니다.

본 학습 프로젝트와 게임 배포물에 포함하기 위해 제작한 자산입니다. 별도 외부 샘플의 라이선스는 없으며, 프로젝트 전체에 오픈소스 라이선스를 새로 지정한 것은 아닙니다.

## 한국어 글꼴

- 글꼴: Noto Sans KR 가변 글꼴. 화면에는 weight 400을 지정했습니다.
- 파일: `fonts/NotoSansKR_261022.ttf`.
- 배포 출처: [Google Fonts의 Noto Sans KR 원본 폴더](https://github.com/google/fonts/tree/main/ofl/notosanskr).
- 다운로드: `https://raw.githubusercontent.com/google/fonts/main/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf`.
- 저작권 표기: Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'.
- 라이선스: SIL Open Font License 1.1. 원문 전체는 `fonts/NotoSansKR_OFL_261022.txt`에 포함했습니다. 글꼴을 게임과 함께 전달할 때 이 파일도 포함합니다. 글꼴 자체만 별도로 판매하지 않습니다.
- SHA-256: `194018E6B2B293A7964F037B25C0249CE1418BC9AB3C971060A03AA57861E252`.

시스템에 설치된 맑은 고딕을 복사해 배포하지 않습니다. 22단계 시제품의 시스템 글꼴 참조는 학습 기록으로만 남기고 현재 전체 게임은 포함한 Noto 글꼴을 사용합니다.

## 대본과 화면

현재 전체 대본은 `data/story_dialogue_261022.json`입니다. 이 프로젝트에서 작성한 오리지널 이야기이며 외부 소설·게임 대사를 인용하지 않았습니다. UI는 Godot Control과 스타일 리소스로 구성했습니다. 선택적 `cg_next_cup`은 미제작이며 저녁 배경으로 대체합니다.

Godot 엔진의 라이선스와 실제 배포 파일에 필요한 고지는 29단계 패키징 때 함께 확인합니다. 현재는 엔진 실행 파일을 이 프로젝트에 포함하지 않습니다.
