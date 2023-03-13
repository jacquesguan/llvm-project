add_llvm_component_group(TGXXX)

set(LLVM_TARGET_DEFINITIONS TGXXX.td)

add_llvm_target(TGXXXCodeGen  
  TGXXXTargetMachine.cpp

  ADD_TO_COMPONENT
  TGXXX
  )

add_subdirectory(TargetInfo)
add_subdirectory(MCTargetDesc)
