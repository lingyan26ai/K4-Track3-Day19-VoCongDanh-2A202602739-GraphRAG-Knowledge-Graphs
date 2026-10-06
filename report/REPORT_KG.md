# Báo cáo Day 19 — Flat RAG vs GraphRAG

**Họ tên:** Võ Công Danh  **MSSV:** 2A202602739  **Ngày:** 06/10/2026

> Kỳ vọng và thang điểm: `SUBMISSION.md`. Mọi số liệu phải khớp với `ket_qua_benchmark_kg.txt`. Bản thiết kế ontology nộp riêng ở `report/ONTOLOGY.md`.

## 1. Chi phí (10 điểm)

Dán 2 bảng `Indexing` và `Querying` từ `ket_qua_benchmark_kg.txt`:

```
== Indexing (one-off)
pipeline  calls    in_tok  out_tok       USD  seconds
flat        176     56072        0   0.00112    103.7
graph       196     91958     4647   0.00929    169.9

== Querying (mean per question)
pipeline  recall  judge   in_tok  out_tok       USD  seconds
flat        0.43   1.00      694       47   0.00013     2.10
graph       0.83   1.67     3778       78   0.00061     2.74
```

| Chỉ số | Flat | Graph | Graph / Flat |
| --- | --- | --- | --- |
| Indexing USD | 0.00112 | 0.00929 | ×8.29 |
| Indexing giây | 103.7 | 169.9 | ×1.64 |
| Mỗi câu: USD | 0.00013 | 0.00061 | ×4.69 |
| Mỗi câu: giây | 2.10 | 2.74 | ×1.30 |
| Mỗi câu: in_tok | 694 | 3778 | ×5.44 |

Tỉ lệ tính từ số đã làm tròn trong file kết quả. Lần chạy dùng OpenRouter `openai/gpt-4o-mini`, embedding `openai/text-embedding-3-small`, top-k = 3, chunk size = 800; có 176 chunk, 204 node và 382 cạnh. Chi phí USD là ước tính của code; các bảng pipeline không tính chi phí LLM chấm điểm.

**Chi phí tăng thêm đến từ đâu?** (2–3 câu)
> Khi dựng hệ thống, GraphRAG thêm 20 lần gọi LLM trích xuất tin, tăng khoảng 0.00817 USD và 66.2 giây; phần luật dùng regex. Khi trả lời, dữ kiện graph làm số token đầu vào trung bình tăng từ 694 lên 3778, chi phí mỗi câu từ 0.00013 lên 0.00061 USD. Với số liệu lần chạy này, GraphRAG không có điểm hòa vốn nếu chỉ xét tiền API vì cả chi phí dựng và chi phí mỗi câu đều cao hơn; lợi ích cần cân nhắc là chất lượng trả lời.

## 2. Từng câu hỏi (10 điểm)

| Câu | Loại | Flat recall / judge | Graph recall / judge | Thắng | Vì sao (1 câu) |
| --- | --- | --- | --- | --- | --- |
| Q1 | single-hop-law | 1.00 / 2 | 1.00 / 2 | Hòa | Cả hai đều nêu đủ định nghĩa tiền chất. |
| Q2 | single-hop-news | 1.00 / 2 | 1.00 / 2 | Hòa | Cả hai nêu đúng Trần Thanh Tuấn và Trần Minh Tâm. |
| Q3 | cross-kb | 0.00 / 0 | 1.00 / 2 | Graph | Graph nối được mức án 36 tháng với Điều 251 và khung cơ bản; Flat không đủ thông tin. |
| Q4 | cross-kb | 0.00 / 0 | 0.67 / 1 | Graph, nhưng chưa đúng đủ | Graph tìm được hành vi và Điều 255 nhưng trả lời sai mức phạt tối đa. |
| Q5 | cross-kb-multi-hop | 0.60 / 1 | 1.00 / 2 | Graph | Graph nêu đúng khoản 4 Điều 250; Flat chỉ ghi “khoản b)” và thiếu số Điều. |
| Q6 | aggregation | 0.00 / 1 | 0.33 / 1 | Graph nhỉnh hơn recall; judge hòa | Graph có tên Cái Quang Huy nhưng vẫn thiếu tên Lê Minh Thành đầy đủ và vụ Viện Pháp y tâm thần trong đáp án chuẩn. |

Q1–Q2 cho thấy chunk đã đủ cho câu hỏi trong một nguồn. Q3–Q5 cho thấy lợi ích của cầu nối tin–luật, nhưng Q4 vẫn sai và Q6 vẫn thiếu ý. Điểm recall chỉ đo khớp chuỗi từ khóa; ở Q6, Flat có thông tin liên quan nhưng không khớp các tên đầy đủ nên recall bằng 0 trong khi judge bằng 1.

## 3. Phân tích lỗi (20 điểm)

Chọn ít nhất 2 nhóm lỗi trong E1–E6 (`LAB_GUIDE.md` Bước 8.4). Sao chép khung dưới đây cho mỗi lỗi.

### Lỗi E2: Bỏ sót khoản quy định mức phạt tối đa

- **Hiện tượng:** Q4 Graph trả lời mức tối đa là 7 năm, trong khi khoản 4 Điều 255 trong corpus nêu 20 năm hoặc tù chung thân.
- **Bằng chứng:** nguyên văn Q4 Graph trong file benchmark:

> Giang hồ 'Hoàng Nato' bị bắt về hành vi tổ chức sử dụng trái phép chất ma túy. Hành vi này có thể bị phạt tù tối đa 7 năm theo Điều 255 Bộ luật Hình sự.

Truy vấn trên graph sau benchmark:

```cypher
MATCH (:Article {id:'Điều 255 BLHS'})-[:HAS_CLAUSE]->(cl:Clause)
OPTIONAL MATCH (cl)-[:MENTIONS]->(s:Substance)
RETURN cl.number AS number, split(cl.text, '\n')[0] AS first_line,
       count(s) AS substances
ORDER BY number;
```

| number | first_line | substances |
| --- | --- | --- |
| 1 | 1. Người nào tổ chức sử dụng trái phép chất ma túy dưới bất kỳ hình thức nào, thì bị phạt tù từ 02 năm đến 07 năm. | 0 |
| 2 | 2. Phạm tội thuộc một trong các trường hợp sau đây, thì bị phạt tù từ 07 năm đến 15 năm: | 0 |
| 3 | 3. Phạm tội thuộc một trong các trường hợp sau đây, thì bị phạt tù từ 15 năm đến 20 năm: | 0 |
| 4 | 4. Phạm tội thuộc một trong các trường hợp sau đây, thì bị phạt tù 20 năm hoặc tù chung thân: | 0 |
| 5 | 5. Người phạm tội còn có thể bị phạt tiền từ 50.000.000 đồng đến 500.000.000 đồng, phạt quản chế, cấm cư trú từ 01 năm đến 05 năm hoặc tịch thu một phần hoặc toàn bộ tài sản. | 0 |

- **Nguyên nhân:** KG-3 chỉ giữ khoản 1 hoặc khoản có cạnh `MENTIONS` trùng chất của vụ. Các khoản Điều 255 không có cạnh `MENTIONS`, nên khoản 4 bị loại dù đã lưu trong graph. Đây là lỗi chọn ngữ cảnh ở `Neo4jGraph.context`, không phải thiếu Điều luật trong dữ liệu.
- **Đề xuất sửa:** khi câu hỏi yêu cầu mức “tối đa”, lấy đầy đủ khoản của Điều liên quan và yêu cầu LLM phân biệt khung cơ bản với khung cao nhất. Cách này tăng token và độ trễ; chưa áp dụng vào lần benchmark đang báo cáo.

### Lỗi E3: Trùng node chất do khác chữ hoa/thường

- **Hiện tượng:** cùng một chất được lưu thành hai node, ví dụ `Ketamine` và `ketamine`.
- **Bằng chứng:** truy vấn trên graph sau benchmark:

```cypher
MATCH (s:Substance)
WITH toLower(s.name) AS normalized, collect(s.name) AS names
WHERE size(names) > 1
RETURN normalized, names ORDER BY normalized;
```

```
ketamine        ["Ketamine", "ketamine"]
methamphetamine ["methamphetamine", "Methamphetamine"]
```

- **Nguyên nhân:** `add_news_case` dùng `MERGE` theo nguyên văn `s.name` từ LLM. `extract_news_cases` chuẩn hóa tội danh nhưng chưa chuẩn hóa tên chất, nên constraint theo `name` vẫn cho phép hai cách viết khác nhau. Truy vấn theo tên chuẩn hoặc đường nối `Substance` có thể bỏ sót node còn lại.
- **Đề xuất sửa:** chuẩn hóa tên chất trong `extract_news_cases` bằng bảng tên chuẩn/alias trước khi ghi graph, giữ tên gốc nếu không xác định được. Bước này không cần thêm API nhưng cần quản lý danh sách đồng nghĩa; không nên ép mọi tên lạ sang chất gần giống. Chưa áp dụng vào lần benchmark đang báo cáo.

## 4. Kết luận (5 điểm)

Khi nào nên dùng KG, khi nào Flat RAG là đủ? Dẫn số liệu ở mục 1–2.
> Với dữ liệu và cấu hình lần chạy này, GraphRAG phù hợp hơn cho câu hỏi cần nối người/vụ trong tin tức với Điều và khoản luật: Q3 đạt recall 1.00, judge 2 thay vì 0.00, judge 0; Q5 tăng từ 0.60/1 lên 1.00/2. Recall trung bình tăng từ 0.43 lên 0.83 và judge từ 1.00 lên 1.67, đổi lại chi phí dựng tăng khoảng 8.29 lần và chi phí mỗi câu tăng 4.69 lần. Với câu hỏi trong một nguồn như Q1–Q2, Flat RAG đã đạt đủ điểm và có chi phí thấp hơn. GraphRAG hiện vẫn cần sửa cách chọn khoản và chuẩn hóa thực thể; Q4 và Q6 cho thấy có graph chưa bảo đảm trả lời đầy đủ. Đây là kết quả một lần chạy trên 6 câu, chưa đủ để khái quát cho bộ dữ liệu lớn hơn.

## 5. Tự kiểm (5 điểm)

Kết quả đã chạy trước benchmark ngày 06/10/2026. Lệnh `--check` dùng toàn bộ luật và 1 bài báo; số node/cạnh dưới đây là của graph kiểm tra nhỏ, không phải graph benchmark đầy đủ.

```
$ pytest tests/ -q
48 passed in 0.07s

$ python bench_kg.py --check
[OK] Dữ liệu: 18 điều luật, 20 bài báo
[OK] KG-1 link_entity
[OK] Neo4j kết nối được
[provider] chat = openrouter:openai/gpt-4o-mini | embedding = openrouter:openai/text-embedding-3-small
[OK] KG-2 build_graph: 146 node / 289 cạnh, đường xuyên 2 KB dài 2 cạnh
[OK] KG-3 context: 13 dữ kiện, có Điều 251
[OK] KG-4 GraphRAGAgent.answer
[OK] Chi phí check: 1 lần gọi LLM, $0.00064. Graph nhỏ (luật + 1 bài) vẫn còn trong Neo4j để bạn xem; chạy --judge để dựng graph đầy đủ.
```

Ảnh Neo4j: `report/img/kg_count.png`, `report/img/kg_cross_kb.png`, `report/img/kg_my_case.png`.
Người đã chọn cho `kg_my_case.png`: Cái Quang Huy (đã kiểm tra graph có đường tới Điều luật; ảnh đã lưu).

## Vấn đề gặp phải (không tính điểm)

Lỗi kết nối Neo4j ban đầu đã được giải quyết; `--check` và benchmark đã chạy thành công. Các hạn chế E2, E3 ở trên vẫn còn trong bản code được đo. Đã lưu nguyên ba ảnh Neo4j do người làm bài cung cấp. Thanh bên trái trong ảnh vẫn hiển thị số đếm cũ; bảng Q-A khớp 204 node của benchmark. Dòng truy vấn trong ảnh `kg_my_case.png` bị rút gọn bằng dấu `…`, nên cần chụp lại nếu muốn hiển thị toàn bộ truy vấn.
