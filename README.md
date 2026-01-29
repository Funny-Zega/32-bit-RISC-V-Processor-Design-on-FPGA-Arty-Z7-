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
Bạn hãy chạy lần lượt các bước sau trong Terminal (WSL/Ubuntu):
### Bước 1: Cài đặt thư viện hệ thống

    sudo apt update

    sudo apt install -y autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev libpixman-1-dev python3 python3-pip python3-venv verilator make

### Bước 2: Cài đặt RISC-V Toolchain (Lưu ý: Nếu bạn đã cài Toolchain rồi thì bỏ qua bước này. Bước này mất khoảng 30-45 phút)

#### -Tải về tại thư mục Home
    cd ~
    git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git
    cd riscv-gnu-toolchain

#### -Cấu hình và Biên dịch
    ./configure --prefix=$HOME/riscv32 --with-arch=rv32im --with-abi=ilp32
    make -j$(nproc)

### Bước 3: Cấu hình đường dẫn (PATH)
#### -Thêm vào file cấu hình (chỉ chạy 1 lần duy nhất)
    echo 'export PATH=$HOME/riscv32/bin:$PATH' >> ~/.bashrc

#### -Cập nhật ngay lập tức
    source ~/.bashrc

### Bước 4: Cài đặt môi trường Python

#### -Di chuyển vào thư mục dự án của bạn trước khi chạy
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --upgrade pip
    pip install cocotb cocotb-test pytest

### Bước 5: Kích hoạt môi trường và chạy lệnh kiểm tra
#### -Mở Terminal (WSL) tại thư mục dự án và chạy:

    source .venv/bin/activate

##### -(Nếu dòng lệnh hiện chữ (.venv) ở đầu là thành công)

    pytest -s testbench.py::runCocotbTestsProcessor
    
## 7. Kết Quả Kiểm Thử Mẫu (Sample Test Results)
```markdown
```text
*****************************************************************************************
** TEST                            STATUS    SIM TIME (ns)   REAL TIME (s)   RATIO (ns/s)**
*****************************************************************************************
** testbench.testLui               PASS      32.00           0.11            280.18      **
** testbench.testLuiLui            PASS      40.00           0.02            1910.78     **
** testbench.testAddi3             PASS      44.00           0.02            2056.65     **
** testbench.testMX1               PASS      40.00           0.02            2000.74     **
** testbench.testMX2               PASS      40.00           0.02            1937.57     **
** testbench.testWX1               PASS      44.00           0.02            1969.73     **
** testbench.testWX2               PASS      44.00           0.02            2058.05     **
** testbench.testWD1               PASS      48.00           0.02            2236.86     **
** testbench.testWD2               PASS      48.00           0.02            2356.34     **
** testbench.testX0Bypassing       PASS      52.00           0.02            2522.35     **
** testbench.testBneNotTaken       PASS      44.00           0.02            2081.73     **
** testbench.testBeqNotTaken       PASS      44.00           0.02            2163.61     **
** testbench.testBneTaken          PASS      48.00           0.02            2263.42     **
** testbench.testBeqTaken          PASS      48.00           0.02            2220.53     **
** testbench.testTraceRvLui        PASS      460.00          0.04            12653.11    **
** testbench.testTraceRvBeq        PASS      1572.00         0.07            20971.67    **
** testbench.testLoadUse1          PASS      44.00           0.02            1876.38     **
** testbench.testLoadUse2          PASS      44.00           0.02            2164.98     **
** testbench.testLoadFalseUse      PASS      40.00           0.02            2021.77     **
** testbench.testWMData            PASS      40.00           0.02            1990.56     **
** testbench.testWMAddress         PASS      36.00           0.02            1725.68     **
** testbench.testDiv               PASS      68.00           0.02            3396.00     **
** testbench.test2DivIndependent   PASS      72.00           0.02            3330.69     **
** testbench.test8DivIndependent   PASS      96.00           0.02            4214.01     **
** testbench.test2DivDependent     PASS      104.00          0.02            4700.56     **
** testbench.testDivNonDiv         PASS      72.00           0.02            3558.10     **
** testbench.testDivUse            PASS      72.00           0.02            3383.99     **
** testbench.testDivToStoreData    PASS      68.00           0.02            3163.56     **
** testbench.testDivToStoreAddress PASS      68.00           0.02            3025.85     **
** testbench.testTraceRvLw         PASS      1392.00         0.07            20066.73    **
** testbench.riscvTest_001         PASS      356.00          0.03            11588.58    **
** testbench.riscvTest_002         PASS      460.00          0.03            13186.60    **
** testbench.riscvTest_003         PASS      2260.00         0.11            20704.30    **
** testbench.riscvTest_004         PASS      2272.00         0.10            22315.41    **
** testbench.riscvTest_005         PASS      2268.00         0.10            23191.72    **
** testbench.riscvTest_006         PASS      2292.00         0.10            21994.08    **
** testbench.riscvTest_007         PASS      2368.00         0.10            23331.75    **
** testbench.riscvTest_008         PASS      2344.00         0.10            23518.37    **
** testbench.riscvTest_009         PASS      2156.00         0.10            22591.49    **
** testbench.riscvTest_010         PASS      2180.00         0.10            22365.25    **
** testbench.riscvTest_011         PASS      2148.00         0.10            21237.94    **
** testbench.riscvTest_012         PASS      1040.00         0.06            18454.85    **
** testbench.riscvTest_013         PASS      1068.00         0.06            18784.74    **
** testbench.riscvTest_014         PASS      1212.00         0.06            19504.14    **
** testbench.riscvTest_015         PASS      1272.00         0.06            20245.28    **
** testbench.riscvTest_016         PASS      1248.00         0.07            18242.98    **
** testbench.riscvTest_017         PASS      1076.00         0.05            19915.43    **
** testbench.riscvTest_018         PASS      1196.00         0.06            19348.36    **
** testbench.riscvTest_019         PASS      1196.00         0.06            19811.50    **
** testbench.riscvTest_020         PASS      2156.00         0.09            23334.41    **
** testbench.riscvTest_021         PASS      1216.00         0.06            19682.09    **
** testbench.riscvTest_022         PASS      1572.00         0.07            22032.15    **
** testbench.riscvTest_023         PASS      1716.00         0.08            21934.22    **
** testbench.riscvTest_024         PASS      1816.00         0.08            22166.26    **
** testbench.riscvTest_025         PASS      1572.00         0.08            20939.17    **
** testbench.riscvTest_026         PASS      1672.00         0.08            21759.40    **
** testbench.riscvTest_027         PASS      1588.00         0.07            21632.99    **
** testbench.riscvTest_028         PASS      436.00          0.03            13291.47    **
** testbench.riscvTest_029         PASS      756.00          0.05            16688.15    **
** testbench.riscvTest_030         PASS      448.00          0.03            13482.57    **
** testbench.riscvTest_031         PASS      1392.00         0.07            20116.16    **
** testbench.riscvTest_032         PASS      1336.00         0.07            19840.37    **
** testbench.riscvTest_033         PASS      1372.00         0.07            19630.52    **
** testbench.riscvTest_034         PASS      1272.00         0.07            19283.82    **
** testbench.riscvTest_035         PASS      1272.00         0.07            19137.80    **
** testbench.riscvTest_036         PASS      2416.00         0.11            22875.57    **
** testbench.riscvTest_037         PASS      2388.00         0.10            23010.32    **
** testbench.riscvTest_038         PASS      2176.00         0.10            20999.85    **
** testbench.riscvTest_039         PASS      2156.00         0.09            23377.30    **
** testbench.riscvTest_040         PASS      2156.00         0.09            23477.14    **
** testbench.riscvTest_041         PASS      2156.00         0.09            22915.70    **
** testbench.riscvTest_042         PASS      2156.00         0.09            23138.57    **
** testbench.riscvTest_043         PASS      836.00          0.05            16691.07    **
** testbench.riscvTest_044         PASS      840.00          0.05            17577.43    **
** testbench.riscvTest_045         PASS      836.00          0.05            16815.29    **
** testbench.riscvTest_046         PASS      836.00          0.05            16307.06    **
*****************************************************************************************
** TESTS=76 PASS=76 FAIL=0 SKIP=0            75820.08        5.16            14682.63    **
*****************************************************************************************

