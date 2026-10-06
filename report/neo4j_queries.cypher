// Chạy từng truy vấn trong Neo4j Browser sau khi benchmark hoàn tất.
// Trước mỗi ảnh, nhập :clear riêng để chỉ còn một khung kết quả.
// Chụp cả cửa sổ: thấy ô truy vấn và Results overview; không cắt/chỉnh ảnh.

// Q-A -> report/img/kg_count.png (tab Table)
MATCH (n)
RETURN labels(n)[0] AS label, count(*) AS n
ORDER BY n DESC;

// Q-B -> report/img/kg_cross_kb.png (tab Graph + Results overview)
MATCH p=(:Person)-[:INVOLVED_IN]->(:Case)-[:CHARGED_WITH]->(:Crime)<-[:DEFINES]-(:Article)
RETURN p LIMIT 25;

// Q-D -> report/img/kg_my_case.png
// Dự kiến chọn Cái Quang Huy, có trong corpus; chỉ xác nhận khi truy vấn trả kết quả.
// Nếu không có, lấy một Person từ Q-B, khác Lê Minh Thành, và ghi tên vào báo cáo.
MATCH p=(:Person {name:'Cái Quang Huy'})-[:INVOLVED_IN]->(k:Case)-[:CHARGED_WITH]->(:Crime)<-[:DEFINES]-(:Article)
OPTIONAL MATCH q=(k)-[:INVOLVES|LOCATED_IN]->()
RETURN p, q;

// Đối chiếu ontology với labels và relationships thật.
MATCH (n) RETURN DISTINCT labels(n) AS labels;
MATCH ()-[r]->() RETURN DISTINCT type(r) AS relationship;

// E1: các vụ chưa nối được sang tội danh.
// Đọc lại bài gốc theo doc_id để xác định thiếu cạnh có thực sự là lỗi không.
MATCH (k:Case)
WHERE NOT (k)-[:CHARGED_WITH]->()
RETURN k.name AS case_name, k.doc_id AS doc_id, k.summary AS summary;

// E3: rà tên chất; tên gần giống chỉ là dấu hiệu, cần đối chiếu nguồn.
MATCH (s:Substance)
OPTIONAL MATCH (k:Case)-[:INVOLVES]->(s)
RETURN s.name AS substance, collect(DISTINCT k.doc_id) AS sources
ORDER BY toLower(s.name);

// E5: đối chiếu trực tiếp các vụ MDMA với câu trả lời Q6.
MATCH (k:Case)-[r:INVOLVES]->(s:Substance)
WHERE toLower(s.name) = 'mdma'
RETURN DISTINCT k.name AS case_name, k.doc_id AS doc_id, r.amount AS amount
ORDER BY case_name;

// E6: thiếu tội danh trên quan hệ người-vụ; đối chiếu vai trò và bài gốc.
MATCH (p:Person)-[r:INVOLVED_IN]->(k:Case)
WHERE coalesce(r.charge, '') = ''
RETURN p.name AS person, r.role AS role, k.name AS case_name, k.doc_id AS doc_id;

// Mỗi lỗi được chọn phải có: hiện tượng, Cypher + kết quả/câu trả lời nguyên văn,
// nguyên nhân, đề xuất sửa và đánh đổi. Không kết luận chỉ dựa trên tên nhóm lỗi.
