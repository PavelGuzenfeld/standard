#!/bin/bash -eu
$CXX $CXXFLAGS $LIB_FUZZING_ENGINE tests/fuzz-fixture/fuzz_target.cc -o $OUT/fuzz_target
