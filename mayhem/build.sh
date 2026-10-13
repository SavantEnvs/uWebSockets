#!/usr/bin/env bash
set -euo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -g}"
# DWARF <= 3 so Mayhem's triage can read symbols (SPEC §6.2 item 10): -gdwarf-3 after $SANITIZER_FLAGS wins.
: "${DEBUG_FLAGS:=-gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE

cd "$SRC"

# LeakSanitizer off at build time (the tree frees nothing at exit, by design).
"$CXX" $SANITIZER_FLAGS $DEBUG_FLAGS -c mayhem/lsan_off.cc -o /tmp/lsan_off.o

# The fuzzed code is the header-only src/TopicTree.h, compiled into the harness with the sanitizers.
# helpers.h of this old commit lacks <cstdint>, hence -include cstdint. -O0 keeps trimTree's stack frames big
# enough that its recursion overflows within the 8 KiB input cap Mayhem puts on a libFuzzer input.
cd fuzzing
"$CXX" $SANITIZER_FLAGS $DEBUG_FLAGS -std=c++17 -include cstdint -O0 -I../src TopicTree.cpp /tmp/lsan_off.o \
  -o /mayhem/TopicTree $LIB_FUZZING_ENGINE

# Standalone (non-fuzzer) reproducer.
"$CC" $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main.o
"$CXX" $SANITIZER_FLAGS $DEBUG_FLAGS -std=c++17 -include cstdint -O0 -I../src TopicTree.cpp /tmp/lsan_off.o /tmp/standalone_main.o \
  -o /mayhem/TopicTree-standalone
chmod +x /mayhem/TopicTree /mayhem/TopicTree-standalone

# Functional tests (normal flags, no sanitizers). tests/TopicTree.cpp does not compile at this commit,
# so the tree is covered by mayhem/topictree_test.cpp.
cd "$SRC"
mkdir -p /mayhem/tests-bin
TEST_CXXFLAGS="-std=c++17 -O2 -g"
"$CXX" $TEST_CXXFLAGS tests/HttpRouter.cpp -o /mayhem/tests-bin/HttpRouter
"$CXX" $TEST_CXXFLAGS mayhem/topictree_test.cpp -o /mayhem/tests-bin/TopicTree
