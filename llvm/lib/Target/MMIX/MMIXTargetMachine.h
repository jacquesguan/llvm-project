//=- MMIXTargetMachine.h - Define TargetMachine for MMIX -*- C++ -*-//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares the MMIX specific subclass of TargetMachine.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_MMIX_MMIXTARGETMACHINE_H
#define LLVM_LIB_TARGET_MMIX_MMIXTARGETMACHINE_H

#include "llvm/Target/TargetMachine.h"
#include <optional>

#include "llvm/Target/TargetMachine.h"

namespace llvm {

class MMIXTargetMachine : public LLVMTargetMachine {

public:
  MMIXTargetMachine(const Target &T, const Triple &TT, StringRef CPU,
                    StringRef FS, const TargetOptions &Options,
                    std::optional<Reloc::Model> RM,
                    std::optional<CodeModel::Model> CM, CodeGenOpt::Level OL,
                    bool JIT);
  ~MMIXTargetMachine() override;
};

} // end namespace llvm

#endif // LLVM_LIB_TARGET_MMIX_MMIXTARGETMACHINE_H