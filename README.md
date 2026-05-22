# RV32IM Pipelined Processor 

![Verilog](https://img.shields.io/badge/Language-Verilog-blue?logo=verilog)
![RISC-V](https://img.shields.io/badge/Architecture-RISC--V-red)
![Verification](https://img.shields.io/badge/Verification-Cocotb-green?logo=python)
![Tools](https://img.shields.io/badge/Tools-Verilator%20%7C%20GTKWave-orange)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

## Table of Contents
- [1. Project Description](#1-mô-tả-dự-án-project-description)
- [2. Technologies Used](#2-công-nghệ-sử-dụng-technologies-used)
- [3. Key Features](#3-tính-năng-kỹ-thuật-nổi-bật-key-features)
- [4. Source Structure](#4-cấu-trúc-mã-nguồn-source-structure)
- [5. Architecture Flow](#5-sơ-đồ-hoạt-động-architecture-flow)
- [6. Installation & Usage](#6-hướng-dẫn-cài-đặt--mô-phỏng-installation--usage)
- [7. Sample Test Results](#7-kết-quả-kiểm-thử-mẫu-sample-test-results)

## 1. Project Description

This project is the hardware implementation of a **32-bit RISC-V** microprocessor supporting the **M-Extension** (Multiply/Divide) arithmetic instruction set. The processor is built upon a classic **5-stage pipeline** architecture, focusing on performance optimization through Instruction-Level Parallelism (ILP) and minimizing stall cycles.

A distinctive feature of this design is the integration of advanced Hazard Handling techniques and a **multi-cycle hardware divider** operating in parallel with the main pipeline.

* **Architecture:** 32-bit RISC-V (RV32IM).
* **Pipeline:** 5 stages (Fetch, Decode, Execute, Memory, Writeback).
* **Design Language:** Verilog HDL.
* **Objective:** In-depth study of computer architecture, optimizing throughput and hardware area.

## 2. Technologies Used

* **Language:** Verilog HDL (IEEE 1364-2005).
* **Instruction Set Architecture (ISA):** RISC-V User-Level ISA (RV32IM).
* **Simulation Tools:** Icarus Verilog, ModelSim, or Vivado.
* **Waveform Viewer:** GTKWave.
* **Editor:** VS Code (Verilog extension).

## 3. Key Features

### 3.1. 5-Stage Pipeline
The processor breaks down instruction execution into 5 independent stages: **IF, ID, EX, MEM, WB**. This allows for the overlapping execution of multiple instructions simultaneously to maximize processing throughput.

### 3.2. 8-Stage Pipelined Divider
Instead of using a single-cycle divider (causing significant delay) or stalling the pipeline (causing long stalls), the project integrates a separate Divider Unit:
* **Structure:** 8-stage pipeline operating in parallel with the main processing flow.
* **Algorithm:** Utilizes the Shift-Subtract method with 4 iterations per stage to balance area and speed.
* **Shadow Register:** The datapath uses a chain of shadow registers to track the divide instruction and accurately resolve writeback hazards at the 8th cycle.

### 3.3. Carry Lookahead Adder (CLA)
Utilizes a 32-bit Carry Lookahead Adder (CLA) architecture instead of the traditional Ripple Carry Adder. This technique significantly reduces the critical path at the Execute stage, allowing the microprocessor to operate at a higher clock frequency.

### 3.4. Advanced Hazard Unit
The system automatically ensures data integrity:
* **Data Forwarding (Bypass):** Forwards data from the MEM/WB stages back to the EX stage immediately, resolving data hazards without stalling the pipeline.
* **Load-Use Hazard Detection:** Automatically inserts a 1-cycle stall when it detects a subsequent instruction dependent on data from a preceding Load instruction.
* **Control Hazard Flushing:** Automatically flushes incorrect instructions in the pipeline immediately upon encountering a branch/jump instruction.
* **Structural Hazard Handling:** An arbiter mechanism prevents conflicts when both a divide instruction and a regular instruction attempt to write to the Register File simultaneously.

## 4. Source Structure

| File Name | Description |
| :--- | :--- |
| **`DatapathPipelined.v`** | **Core Module:** Contains the 5-stage pipeline logic, Hazard Unit, Forwarding Unit, and Register File. |
| **`DividerUnsignedPipelined.v`** | **Hardware Divider:** 8-stage pipelined divider, supporting signed and unsigned division. |
| **`cla.v`** | **ALU Adder:** High-speed 32-bit CLA adder. |
| **`mem_initial_contents.hex`** | **Instruction Memory:** Machine code (Hex) used to load into memory during simulation. |

```text
.
├── rtl/                        # Design source code (Verilog Design)
│   ├── DatapathPipelined.v     # Core Module (5-Stage Pipeline)
│   ├── DividerUnsignedPipelined.v # 8-Stage Divider
│   └── cla.v                   # 32-bit CLA Adder
├── testbench/                  # Verification source code
│   ├── testbench.py            # Cocotb Testbench (Python)
│   └── mem_initial_contents.hex # Memory Image (Hex file)
├── sim_build/                  # Compiled files directory
├── README.md                   # Documentation
```
## 5. Architecture Flow

Data moves through the processing stages as follows:
1.  **IF (Fetch):** PC points to the instruction address in the Instruction Memory.
2.  **ID (Decode):** Decodes the instruction and reads the Register File. If it is a Divide instruction, sends a signal to the Divider Unit.
3.  **EX (Execute):** ALU (using CLA) performs computations, or the Divider begins processing. The Forwarding Unit provides the latest data in case of hazards.
4.  **MEM (Memory):** Accesses the Data Memory (for Load/Store instructions).
5.  **WB (Writeback):** A Mux selects the result from the ALU, Memory, or Divider Unit to write back into the Register File.

## 6. Installation & Usage
# --- Begin installation process ---
Running the following steps sequentially in your Terminal (WSL/Ubuntu):
### Step 1: Installing system libraries

    sudo apt update

    sudo apt install -y autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev libpixman-1-dev python3 python3-pip python3-venv verilator make

### Step 2: Install the RISC-V Toolchain (Note: If you have already installed the Toolchain, skip this step. This step takes approximately 30-45 minutes)

#### -Downloading from the Home folder.
    cd ~
    git clone https://github.com/riscv-collab/riscv-gnu-toolchain.git
    cd riscv-gnu-toolchain

#### -Configuration and Compilation
    ./configure --prefix=$HOME/riscv32 --with-arch=rv32im --with-abi=ilp32
    make -j$(nproc)

### Step 3: Configure the path
#### -Add this to the configuration file (run only once).
    echo 'export PATH=$HOME/riscv32/bin:$PATH' >> ~/.bashrc

#### -Update immediately
    source ~/.bashrc

### Step 4: Set up the Python environment

#### -Navigating to your project folder before running.
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --upgrade pip
    pip install cocotb cocotb-test pytest

### Step 5: Activate the environment and run the test command.
#### -Opening Terminal (WSL) in your project directory and run:

    source .venv/bin/activate

##### -(If the command line starts with "(.venv)", it's successful.)

    pytest -s testbench.py::runCocotbTestsProcessor
    
## 7. Sample Test Results

```markdown

*******************************************************************************************
** TEST                            STATUS    SIM TIME (ns)   REAL TIME (s)   RATIO (ns/s)**
*******************************************************************************************
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
*******************************************************************************************
** TESTS=76 PASS=76 FAIL=0 SKIP=0            75820.08        5.16            14682.63    **
*******************************************************************************************


