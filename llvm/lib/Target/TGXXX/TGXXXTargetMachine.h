//===-- TGXXXTargetMachine.h - Define TargetMachine for TGXXX ---*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares the TGXXX specific subclass of TargetMachine.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_TGXXX_TGXXXTARGETMACHINE_H
#define LLVM_LIB_TARGET_TGXXX_TGXXXTARGETMACHINE_H

#include "llvm/Target/TargetMachine.h"

namespace llvm {

class TGXXXTargetMachine : public LLVMTargetMachine {};
} // namespace llvm

#endif
