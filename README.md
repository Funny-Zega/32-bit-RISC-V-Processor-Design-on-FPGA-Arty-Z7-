# RV32IM Pipelined Processor 🚀

## 1. Mô Tả Dự Án (Project Description)

Dự án này là thiết kế hiện thực hóa một bộ vi xử lý **RISC-V 32-bit** hỗ trợ tập lệnh số học **M-Extension** (Nhân/Chia). Vi xử lý được xây dựng dựa trên kiến trúc **Pipeline 5 tầng (5-Stage Pipeline)** cổ điển, tập trung tối ưu hóa hiệu năng thông qua kỹ thuật song song mức lệnh (ILP) và giảm thiểu chu kỳ rỗi (stall).

Điểm đặc biệt của thiết kế là việc tích hợp các kỹ thuật xử lý xung đột (Hazard Handling) tiên tiến và một **bộ chia phần cứng đa chu kỳ (Multi-cycle Hardware Divider)** hoạt động song song với pipeline chính.

* **Kiến trúc:** RISC-V 32-bit (RV32IM).
* **Pipeline:** 5 tầng (Fetch, Decode, Execute, Memory, Writeback).
* **Ngôn ngữ thiết kế:** Verilog HDL.
* **Mục tiêu:** Nghiên cứu kiến trúc máy tính chuyên sâu, tối ưu hóa thông lượng (Throughput) và diện tích phần cứng.

## 2. Công Nghệ Sử Dụng (Technologies Used)

* **Ngôn ngữ:** Verilog HDL (IEEE 1364-2005).
* **Kiến trúc tập lệnh (ISA):** RISC-V User-Level ISA (RV32IM).
* **Công cụ mô phỏng:** Icarus Verilog, ModelSim, hoặc Vivado.
* **Công cụ phân tích sóng:** GTKWave.
* **Editor:** VS Code (Verilog extension).

## 3. Tính Năng Kỹ Thuật Nổi Bật (Key Features)

### 3.1. Đường Ống 5 Tầng (5-Stage Pipeline)
Bộ xử lý chia nhỏ quá trình thực thi lệnh thành 5 giai đoạn độc lập: **IF, ID, EX, MEM, WB**. [cite_start]Điều này cho phép xử lý chồng gối nhiều lệnh cùng lúc để tăng tối đa thông lượng xử lý [cite: 26, 85-227].

### 3.2. Bộ Chia Pipeline 8 Tầng (8-Stage Pipelined Divider)
Thay vì sử dụng bộ chia đơn chu kỳ (gây trễ lớn) hoặc chặn pipeline (gây stall lâu), dự án tích hợp một Divider Unit riêng biệt:
* [cite_start]**Cấu trúc:** 8 tầng pipeline hoạt động song song với luồng xử lý chính [cite: 242-248].
* [cite_start]**Thuật toán:** Sử dụng phương pháp dịch-trừ (Shift-Subtract) với 4 lần lặp mỗi tầng (4 iterations/stage) để cân bằng giữa diện tích và tốc độ [cite: 250-252].
* [cite_start]**Shadow Register:** Datapath sử dụng một chuỗi thanh ghi bóng để theo dõi lệnh chia và xử lý xung đột ghi (Writeback Hazard) chính xác tại chu kỳ thứ 8 [cite: 177-190].

### 3.3. Bộ Cộng Nhanh (Carry Lookahead Adder - CLA)
Sử dụng kiến trúc cộng nhìn trước số nhớ (CLA) 32-bit thay vì Ripple Carry Adder truyền thống. [cite_start]Kỹ thuật này giảm đáng kể đường trễ (Critical Path) tại tầng Execute, cho phép vi xử lý hoạt động ở tần số xung nhịp cao hơn [cite: 1-25].

### 3.4. Hệ Thống Xử Lý Xung Đột (Advanced Hazard Unit)
Hệ thống tự động đảm bảo tính toàn vẹn dữ liệu:
* **Data Forwarding (Bypass):** Chuyển dữ liệu từ tầng MEM/WB quay ngược lại EX ngay lập tức, giải quyết Data Hazard mà không cần dừng pipeline [cite: 142-152].
* **Load-Use Hazard Detection:** Tự động chèn 1 chu kỳ Stall khi phát hiện lệnh sau phụ thuộc vào dữ liệu từ lệnh Load trước đó.
* **Control Hazard Flushing:** Tự động hủy (Flush) các lệnh sai trong đường ống ngay lập tức khi gặp lệnh rẽ nhánh (Branch/Jump) [cite: 82, 89-90].
* **Structural Hazard Handling:** Cơ chế trọng tài (arbiter) ngăn xung đột khi lệnh Chia và lệnh thường cùng muốn ghi vào Register File [cite: 76-81].

## 4. Cấu Trúc Mã Nguồn (Source Structure)

| Tên File | Chức năng |
| :--- | :--- |
| **`DatapathPipelined.v`** | **Core Module:** Chứa logic 5 tầng pipeline, Hazard Unit, Forwarding Unit và Register File. |
| **`DividerUnsignedPipelined.v`** | **Hardware Divider:** Bộ chia pipeline 8 tầng, hỗ trợ chia có dấu và không dấu. |
| **`cla.v`** | **ALU Adder:** Bộ cộng CLA 32-bit tốc độ cao. |
| **`mem_initial_contents.hex`** | **Instruction Memory:** Mã máy (Hex) dùng để nạp vào bộ nhớ khi mô phỏng. |

## 5. Sơ Đồ Hoạt Động (Architecture Flow)

Dữ liệu di chuyển qua các tầng xử lý như sau:
1.  **IF (Fetch):** PC trỏ tới địa chỉ lệnh trong Instruction Memory.
2.  **ID (Decode):** Giải mã lệnh, đọc Register File. Nếu là lệnh Chia, gửi tín hiệu sang Divider Unit.
3.  **EX (Execute):** ALU (dùng CLA) tính toán hoặc Divider bắt đầu xử lý. Forwarding Unit cấp dữ liệu mới nhất nếu có xung đột.
4.  **MEM (Memory):** Truy cập Data Memory (cho lệnh Load/Store).
5.  **WB (Writeback):** Mux lựa chọn kết quả từ ALU, Memory hoặc Divider Unit để ghi lại vào Register File.

## 6. Hướng Dẫn Cài Đặt & Mô Phỏng (Installation & Usage)

### Bước 1: Cài đặt công cụ
Bạn cần cài đặt **Icarus Verilog** (để biên dịch) và **GTKWave** (để xem sóng).
* **Linux:** `sudo apt install iverilog gtkwave`
* **Windows:** Tải bộ cài tại [bleyer.org/icarus](http://bleyer.org/icarus/).

### Bước 2: Chuẩn bị mã máy
Đảm bảo file `mem_initial_contents.hex` nằm cùng thư mục với các file mã nguồn.

### Bước 3: Biên dịch và Chạy
Mở terminal tại thư mục dự án và chạy lệnh:

```bash
# 1. Biên dịch toàn bộ source code
iverilog -o cpu_core DatapathPipelined.v cla.v DividerUnsignedPipelined.v

# 2. Chạy mô phỏng
vvp cpu_core
