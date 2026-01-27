# Bộ Xử Lý RV32IM Pipelined (RV32IM Pipelined Processor)

Kho chứa (repository) này bao gồm mã nguồn Verilog hiện thực hóa một bộ vi xử lý RISC-V 32-bit (RV32IM). Thiết kế nổi bật với kiến trúc đường ống (pipeline) 5 tầng cổ điển, được mở rộng với bộ chia phần cứng đa chu kỳ phức tạp và bộ cộng nhanh Carry Lookahead Adder. Bộ xử lý xử lý các xung đột dữ liệu (data hazards) thông qua kỹ thuật chuyển tiếp (forwarding) và xung đột điều khiển (control hazards) thông qua kỹ thuật làm rỗng đường ống (flushing), hỗ trợ đầy đủ phần mở rộng **M-Extension** (Nhân và Chia).

## 📂 Cấu Trúc Dự Án

| Tên File | Mô tả |
| :--- | :--- |
| **`DatapathPipelined.v`** | File chính chứa **logic pipeline 5 tầng** (Fetch, Decode, Execute, Memory, Writeback), các khối xử lý Xung đột/Forwarding, và Bộ thanh ghi (Register File). [cite_start]File này cũng bao gồm **Bộ nhớ dữ liệu (Data Memory)** và module **`Processor`** (lớp vỏ ngoài cùng) dùng cho mô phỏng [cite: 227-241]. |
| **`DividerUnsignedPipelined.v`** | Một **bộ chia phần cứng pipeline 8 tầng**. [cite_start]Nó thực hiện phép chia 32-bit sử dụng thuật toán dịch-trừ (4 lần lặp mỗi tầng) [cite: 242-260]. |
| **`cla.v`** | Bộ cộng 32-bit **Carry Lookahead Adder (CLA)**. [cite_start]Được sử dụng bởi ALU để thực hiện phép cộng và trừ tốc độ cao [cite: 1-25]. |
| **`mem_initial_contents.hex`** | Mã máy dưới dạng thập lục phân (hexadecimal) được dùng để khởi tạo Bộ nhớ lệnh (Instruction Memory) cho quá trình mô phỏng/kiểm thử. |

## 🚀 Các Tính Năng Nổi Bật

### 1. Kiến Trúc Pipeline 5 Tầng

Bộ xử lý thực hiện các giai đoạn chuẩn của RISC-V:

* **IF (Instruction Fetch):** Nạp lệnh từ bộ nhớ.
* **ID (Instruction Decode):** Giải mã opcode, đọc Bộ thanh ghi và tạo tín hiệu điều khiển.
* **EX (Execute):** Thực hiện các phép toán ALU và tính toán địa chỉ rẽ nhánh.
* **MEM (Memory):** Truy cập Bộ nhớ dữ liệu cho các lệnh Load/Store.
* **WB (Writeback):** Ghi kết quả ngược lại vào Bộ thanh ghi.

### 2. Mở Rộng RV32M (Nhân & Chia)

* **Phép Nhân (`MUL`, `MULH`, v.v.):** Được xử lý ngay trong tầng Execute.
* **Phép Chia (`DIV`, `REM`, v.v.):**
    * Sử dụng một **Bộ chia Pipeline 8 tầng** chuyên dụng được định nghĩa trong `DividerUnsignedPipelined.v`.
    * Hỗ trợ chia Có dấu và Không dấu.
    * [cite_start]Tích hợp một **Shadow Pipeline (Đường ống bóng)** trong Datapath để theo dõi các lệnh chia khi chúng di chuyển, ngăn chặn xung đột cấu trúc tại tầng Writeback [cite: 177-190].

### 3. Xử Lý Xung Đột Nâng Cao (Advanced Hazard Handling)

* [cite_start]**Data Hazards (Xung đột dữ liệu):** Được giải quyết bằng **Bộ Forwarding** giúp chuyển tiếp dữ liệu từ các tầng MEM, WB, hoặc từ **Bộ Chia (Divider Unit)** trực tiếp đến tầng EX (đầu vào ALU) [cite: 142-156].
* **Load-Use Hazards:** Tự động phát hiện sự phụ thuộc vào lệnh Load và chèn một chu kỳ chờ (stall/bubble).
* [cite_start]**Structural Hazards (Xung đột cấu trúc - Divider):** Logic được cài đặt để dừng pipeline nếu kết quả phép chia xung đột với việc ghi lại (writeback) của một lệnh thông thường, hoặc nếu các toán hạng chia chưa sẵn sàng [cite: 76-81].
* **Control Hazards (Xung đột điều khiển):** Tự động xóa (Flush) các thanh ghi pipeline ở tầng Fetch/Decode khi thực hiện Rẽ nhánh (Branch) hoặc Nhảy (Jump).

### 4. Số Học Hiệu Năng Cao

* **CLA (Carry Lookahead Adder):** Thay thế bộ cộng ripple-carry tiêu chuẩn trong ALU để giảm độ trễ đường dẫn tới hạn (critical path delay) trong các phép toán số học.

## 🛠 Hỗ Trợ Tập Lệnh (RV32IM)

Bộ xử lý hỗ trợ các nhóm opcode sau:

* **Số học/Logic:** `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `SRA`, `SLT`, `SLTU`.
* **Tức thời (Immediate):** `ADDI`, `ANDI`, `ORI`, `XORI`, `SLLI`, `SRLI`, `SRAI`, `SLTI`, `SLTIU`.
* **Điều khiển luồng:** `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`, `JAL`, `JALR`.
* **Bộ nhớ:** `LW`, `LB`, `LH`, `LBU`, `LHU`, `SW`, `SB`, `SH`.
* **Tức thời cao (Upper Immediate):** `LUI`, `AUIPC`.
* **M-Extension:** `MUL`, `MULH`, `MULHSU`, `MULHU`, `DIV`, `DIVU`, `REM`, `REMU`.
* **Hệ thống:** `ECALL` (được ánh xạ tới `OpcodeEnviron` để dừng mô phỏng).

## 📐 Sơ Đồ Kiến Trúc (Mô tả dạng văn bản)

```mermaid
graph TD
    Fetch[Nạp Lệnh] --> Decode[Giải Mã]
    Decode --> Execute[Thực Thi]
    Execute --> Memory[Bộ Nhớ]
    Memory --> Writeback[Ghi Lại]
    
    subgraph "M-Extension"
    Execute -- "Bắt đầu Chia" --> Divider[Bộ Chia Pipeline 8 Tầng]
    Divider -- "Kết quả (Độ trễ 8)" --> Writeback
    end
    
    ForwardingUnit -- "Bypass từ MEM/WB/Div" --> Execute
    HazardUnit -- "Stall/Flush" --> Fetch & Decode
