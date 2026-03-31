# ♟️ Swift Chess Pro - AI & PvP Edition

**Swift Chess Pro** là một ứng dụng cờ vua hiệu năng cao dành cho hệ điều hành macOS, được phát triển hoàn toàn bằng **SwiftUI**. Dự án này kết hợp giao diện người dùng hiện đại, tinh tế với bộ não AI được tối ưu hóa từ thuật toán Python, mang lại trải nghiệm chơi cờ mượt mà và đầy thử thách.

## ✨ Tính năng nổi bật

### 🎮 Chế độ chơi
- **Người vs Người (PvP):** Đấu trí trực tiếp với bạn bè trên cùng một máy Mac.
- **Người vs Máy (AI):** Hệ thống AI tích hợp với 3 cấp độ khó:
  - **Dễ:** Di chuyển ngẫu nhiên, ưu tiên ăn quân đối phương.
  - **Trung bình:** Tính toán giá trị quân cờ để đưa ra nước đi tối ưu nhất trong lượt.
  - **Khó:** Sử dụng thuật toán **Minimax** kết hợp bảng điểm **Heuristics** (vị trí quân cờ) để dự đoán và ngăn chặn chiến thuật của người chơi.

### 📜 Luật chơi đầy đủ (International Chess Rules)
- **Nhập thành (Castling):** Hỗ trợ nhập thành gần và xa theo đúng luật quốc tế.
- **Phong cấp (Pawn Promotion):** Khi Tốt chạm đáy, menu chọn quân (Hậu, Xe, Tượng, Mã) sẽ hiển thị với hiệu ứng mờ nền.
- **Kiểm tra trạng thái:** Tự động nhận diện chiếu tướng (Check), chiếu bí (Checkmate) và hòa cờ (Stalemate).
- **Nước đi hợp lệ:** Hệ thống mô phỏng nước đi giả định để ngăn người chơi thực hiện các nước đi khiến Vua bị chiếu.

### 🛠 Tiện ích hỗ trợ
- **Hệ thống tọa độ:** Hiển thị chuẩn đại số (Algebraic notation) với các cột A-H và hàng 1-8.
- **Nhật ký nước đi (Move Log):** Lưu trữ và hiển thị danh sách các nước đi đã thực hiện (VD: ♙E2→E4).
- **Hoàn tác (Undo) không giới hạn:** Cho phép người dùng quay lại bất kỳ nước đi nào, kể cả nước đi của AI, để nghiên cứu chiến thuật.
- **AI Thinking Delay:** Máy sẽ chờ 1.5 giây trước khi phản hồi để tạo cảm giác tự nhiên như đang đối đầu với người thật.

## 🛠 Cài đặt và Chạy ứng dụng

### Yêu cầu hệ thống
- Máy tính chạy **macOS 13.0** trở lên.
- Đã cài đặt **Xcode 5.9** và **Xcode 15.0** trở lên (để build từ source).

### Các bước thực hiện
1. **Tải mã nguồn:**
   ```bash
   git clone https://github.com/conchocon154/Chess_Ai
   ```
2. **Mở dự án:**

    - Khởi động Xcode.

    - Chọn ```Open another project... ```và tìm đến ```file ContentView.swift``` hoặc thư mục dự án.

3. **Biên dịch và Chạy:**

    - Chọn thiết bị mục tiêu là ```My Mac```.

    - Nhấn ```Command + R``` để bắt đầu ván cờ.