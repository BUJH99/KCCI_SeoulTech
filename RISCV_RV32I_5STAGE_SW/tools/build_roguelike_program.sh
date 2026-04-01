#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROGUELIKE_DIR="${PROJECT_ROOT}/src/programs/roguelike"
BUILD_DIR="${PROJECT_ROOT}/output/roguelike_build"

TOOLCHAIN_DIR_DEFAULT="/tmp/xpack-riscv-none-elf-gcc-15.2.0-1"
TOOLCHAIN_DIR="${RISCV_TOOLCHAIN_DIR:-${TOOLCHAIN_DIR_DEFAULT}}"
CC="${TOOLCHAIN_DIR}/bin/riscv-none-elf-gcc"
OBJCOPY="${TOOLCHAIN_DIR}/bin/riscv-none-elf-objcopy"
OBJDUMP="${TOOLCHAIN_DIR}/bin/riscv-none-elf-objdump"

mkdir -p "${BUILD_DIR}"

if [[ ! -x "${CC}" ]]; then
  echo "[ERROR] RISC-V toolchain not found: ${CC}" >&2
  echo "        Set RISCV_TOOLCHAIN_DIR or install the xPack toolchain first." >&2
  exit 1
fi

COMMON_FLAGS=(
  -march=rv32i
  -mabi=ilp32
  -mstrict-align
  -mno-save-restore
  -msmall-data-limit=0
  -ffreestanding
  -fno-builtin
  -fno-common
  -fno-jump-tables
  -fno-tree-switch-conversion
  -fno-asynchronous-unwind-tables
  -fno-unwind-tables
  -fdata-sections
  -ffunction-sections
  -Wall
  -Wextra
  -Werror
  -Os
)

"${CC}" "${COMMON_FLAGS[@]}" -S \
  "${ROGUELIKE_DIR}/roguelike_port.c" \
  -o "${ROGUELIKE_DIR}/Roguelike.s"

"${CC}" "${COMMON_FLAGS[@]}" -c \
  "${ROGUELIKE_DIR}/start.S" \
  -o "${BUILD_DIR}/start.o"

"${CC}" "${COMMON_FLAGS[@]}" -c \
  "${ROGUELIKE_DIR}/roguelike_port.c" \
  -o "${BUILD_DIR}/roguelike_port.o"

"${CC}" "${COMMON_FLAGS[@]}" \
  -nostdlib \
  -nostartfiles \
  -Wl,--gc-sections \
  -Wl,-Map="${BUILD_DIR}/Roguelike.map" \
  -T "${ROGUELIKE_DIR}/linker.ld" \
  "${BUILD_DIR}/start.o" \
  "${BUILD_DIR}/roguelike_port.o" \
  -lgcc \
  -o "${BUILD_DIR}/Roguelike.elf"

if "${OBJDUMP}" -h "${BUILD_DIR}/Roguelike.elf" | grep -E '\.rodata|\.data|\.sdata' >/dev/null; then
  echo "[ERROR] Unexpected initialized data section detected in Roguelike.elf" >&2
  "${OBJDUMP}" -h "${BUILD_DIR}/Roguelike.elf" >&2
  exit 1
fi

"${OBJDUMP}" -d "${BUILD_DIR}/Roguelike.elf" > "${BUILD_DIR}/Roguelike.disasm"
"${OBJCOPY}" -O binary --only-section=.text "${BUILD_DIR}/Roguelike.elf" "${BUILD_DIR}/Roguelike.bin"
python3 "${PROJECT_ROOT}/tools/elf_text_to_mem.py" "${BUILD_DIR}/Roguelike.bin" "${ROGUELIKE_DIR}/Roguelike.mem"

TEXT_SIZE="$("${OBJDUMP}" -h "${BUILD_DIR}/Roguelike.elf" | awk '/\.text[[:space:]]/ { print "0x"$3 }')"
echo "[OK] Built Roguelike program image."
echo "     ELF : ${BUILD_DIR}/Roguelike.elf"
echo "     MEM : ${ROGUELIKE_DIR}/Roguelike.mem"
echo "     ASM : ${ROGUELIKE_DIR}/Roguelike.s"
echo "     TEXT: ${TEXT_SIZE:-unknown}"
