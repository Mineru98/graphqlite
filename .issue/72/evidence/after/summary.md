# after — DDL 요약 JSON 반환 (수정 후)

코어(extension.c)가 {"nodes_created":N,"relationships_created":M} JSON 반환. 세 바인딩이 구조화 row 로 파싱.

## end-to-end 검증 (실제 재빌드된 코어)
```
DDL rows : [{"nodes_created":1,"relationships_created":0}]
columns  : ["nodes_created","relationships_created"]
```

## 검증
- C 코어 재빌드: make extension 성공 (brew bison 3.8.2 필요; 시스템 bison 2.3 은 %code 미지원)
- TS 단위 테스트 (result.test.ts): 12 pass / 0 fail (신규 JSON 파싱 케이스 포함)
- 실제 확장 통합: CREATE 실행 → JSON 객체 반환 확인 (위 로그)
- Rust 회귀: cargo test 285 passed / 0 fail (새 코어 dylib) — 기존 동작 불변
- Python: DDL 통계 전용 파서 없음 → JSON 자동 파싱으로 개선, 소스 무변경

## 하위호환
- TS parseMutationSummary: JSON 우선 + 평문 정규식 폴백 → pre-#72 문자열도 계속 파싱
