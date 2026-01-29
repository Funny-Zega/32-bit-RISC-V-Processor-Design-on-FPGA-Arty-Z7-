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
* **Cấu trúc:** 8 tầng pipeline hoạt động song song với luồng xử lý chính [cite: 242-248].
* **Thuật toán:** Sử dụng phương pháp dịch-trừ (Shift-Subtract) với 4 lần lặp mỗi tầng (4 iterations/stage) để cân bằng giữa diện tích và tốc độ [cite: 250-252].
* **Shadow Register:** Datapath sử dụng một chuỗi thanh ghi bóng để theo dõi lệnh chia và xử lý xung đột ghi (Writeback Hazard) chính xác tại chu kỳ thứ 8 [cite: 177-190].

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
# --- Bắt đầu quy trình cài đặt ---

# 1. Cập nhật hệ thống và cài đặt tất cả thư viện phụ thuộc cho Toolchain và Verilator
sudo apt update && sudo apt install -y autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev libpixman-1-dev python3 python3-pip python3-venv verilator make

# 2. Tải và biên dịch RISC-V GNU Toolchain (Lưu ý: Bước này tốn nhiều thời gian nhất)
# Kiểm tra nếu chưa có thư mục toolchain thì mới tải về
if [ ! -d "riscv-gnu-toolchain" ]; then
    git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git
fi
cd riscv-gnu-toolchain
# Cấu hình biên dịch cho kiến trúc RV32IM (Integer + Multiply) và ABI ilp32
./configure --prefix=$HOME/riscv32 --with-arch=rv32im --with-abi=ilp32
# Bắt đầu biên dịch đa luồng
make -j$(nproc)
cd .. # Quay trở lại thư mục dự án

# 3. Thêm Toolchain vào biến môi trường (PATH) để hệ thống nhận diện lệnh riscv32-gcc
# Lệnh này thêm vào file cấu hình để dùng được vĩnh viễn cho các lần sau
if ! grep -q "$HOME/riscv32/bin" ~/.bashrc; then
    echo 'export PATH=$HOME/riscv32/bin:$PATH' >> ~/.bashrc
fi
export PATH=$HOME/riscv32/bin:$PATH # Cập nhật ngay cho phiên hiện tại

# 4. Kiểm tra cài đặt Toolchain
riscv32-unknown-elf-gcc --version

# 5. Thiết lập môi trường ảo Python và cài đặt thư viện Test
# Tạo thư mục ảo .venv nếu chưa có
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
# Kích hoạt môi trường và cài đặt cocotb, pytest
source .venv/bin/activate
pip install --upgrade pip
pip install cocotb cocotb-test pytest

echo ">>> CÀI ĐẶT HOÀN TẤT. MÔI TRƯỜNG ĐÃ SẴN SÀNG!"
