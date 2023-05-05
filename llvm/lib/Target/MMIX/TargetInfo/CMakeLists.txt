add_llvm_component_library(
  LLVMMMIXInfo
  MMIXTargetInfo.cpp

  LINK_COMPONENTS
  Support

  ADD_TO_COMPONENT
  MMIX
  )