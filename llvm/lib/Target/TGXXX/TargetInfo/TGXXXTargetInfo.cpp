//===-- TGXXXTargetInfo.cpp - TGXXX target implementation -------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "TargetInfo/TGXXXTargetInfo.h"
#include "llvm/MC/TargetRegistry.h"

using namespace llvm;

Target &llvm::getTheTGXXXTarget() {
  static Target TheTGXXXTarget;
  return TheTGXXXTarget;
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeTGXXXTargetInfo() {
  RegisterTarget<Triple::tgxxx, /*HasJIT=*/true> X(getTheTGXXXTarget(),
                                                   "systemz", "TGXXX", "TGXXX");
}
